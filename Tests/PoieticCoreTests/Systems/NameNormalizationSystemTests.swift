//
//  NameNormalizationSystemTests.swift
//  poietice-core
//
//  Created by Stefan Urbanek on 31/08/2026.
//

import Testing
@testable import PoieticCore

// MARK: - Test model


// MARK: - NormalizedName component

@Suite struct NormalizedNameTests {

    @Test func normalizeDisplayTrimsWhitespace() {
        #expect(NormalizedName.displayName(for: "  population growth ") == "population growth")
        #expect(NormalizedName.displayName(for: "\t population growth\n ") == "population growth")
    }

    @Test func normalizeDisplayCollapsesWhitespaceRuns() {
        #expect(NormalizedName.displayName(for: "population  growth") == "population growth")
        #expect(NormalizedName.displayName(for: "A\t \nB") == "A B")
        #expect(NormalizedName.displayName(for: "A\nB") == "A B")
    }

    @Test func normalizeTrimsWhitespace() {
        #expect(NormalizedName.normalize("  population growth ") == "population_growth")
        #expect(NormalizedName.normalize("\tpopulation growth\n") == "population_growth")
    }

    @Test func normalizeCollapsesWhitespaceRuns() {
        #expect(NormalizedName.normalize("population  growth") == "population_growth")
        #expect(NormalizedName.normalize("a\tb") == "a_b")
        #expect(NormalizedName.normalize("a\nb") == "a_b")
    }

    @Test func normalizeUnderscoreAndSpaceAreEquivalent() {
        #expect(NormalizedName.normalize("population growth") == "population_growth")
        #expect(NormalizedName.normalize("population_growth") == "population_growth")
    }

    @Test func normalizeCollapsesMixedUnderscoreAndWhitespaceRuns() {
        #expect(NormalizedName.normalize("population _ growth") == "population_growth")
        #expect(NormalizedName.normalize("population_ growth") == "population_growth")
        #expect(NormalizedName.normalize("population__growth") == "population_growth")
    }

    @Test func normalizePreservesDiacritics() {
        #expect(NormalizedName.normalize("café") != NormalizedName.normalize("cafe"))
    }

    @Test func normalizeLowercase() {
        #expect(NormalizedName.normalize("PoPuLaTiOn GrOwTh") == NormalizedName.normalize("population growth"))
    }

    @Test func normalizePreservesHyphens() {
        #expect(NormalizedName.normalize("a-b") != NormalizedName.normalize("a b"))
    }

    @Test func componentOriginalAndKey() {
        let name = NormalizedName(name: " Population _Growth ")
        #expect(name.displayName == "Population _Growth")
        #expect(name.key == "population_growth")
    }

    @Test func matches() {
        let name = NormalizedName(name: "population growth")
        #expect(name.matches("population_growth"))
        #expect(name.matches("population  growth"))
        #expect(!name.matches("other"))
    }

    @Test func isVisuallyEmpty() {
        #expect(NormalizedName(name: "").isVisuallyEmpty)
        #expect(NormalizedName(name: "   ").isVisuallyEmpty)
        #expect(NormalizedName(name: "_").isVisuallyEmpty)
        #expect(NormalizedName(name: "___").isVisuallyEmpty)
        #expect(NormalizedName(name: "  _  ").isVisuallyEmpty)
        #expect(!NormalizedName(name: "a").isVisuallyEmpty)
    }
}

// MARK: - NameNormalizationSystem

@Suite struct NameNormalizationSystemTests {
    let design: Design
    let frame: TransientPlane

    init() throws {
        self.design = Design(metamodel: TestDomain.NameTestMetamodel)
        self.frame = design.createPlane()
    }

    func accept() throws -> World {
        let plane = try design.accept(frame)
        let world = World(plane: plane)
        try NameNormalizationSystem.update(world)
        return world
    }

    @Test func attachesComponent() throws {
        let object = frame.createNode(TestDomain.Types.NamedNode, name: "population growth")

        let world = try accept()

        let entity = try #require(world.entity(object.objectID))
        let name: NormalizedName = try #require(entity.component())
        #expect(name.displayName == "population growth")
        #expect(name.key == "population_growth")
        #expect(!entity.hasIssues)
    }

    @Test func trimsOriginal() throws {
        // Spec: `original` is the trimmed name (see analysis/Name-Normalisation.md §6).
        //
        // NOTE: The system currently passes the untrimmed name to
        // `NormalizedName(original:)`, so the `original` expectation fails until
        // the system trims before constructing the component.
        let object = frame.createNode(TestDomain.Types.NamedNode, name: "  object \n")

        let world = try accept()

        let entity = try #require(world.entity(object.objectID))
        let name: NormalizedName = try #require(entity.component())
        #expect(name.displayName == "object")
        #expect(name.key == "object")
    }

    @Test func emptyNamesGetEmptyNameIssue() throws {
        let empty = frame.createNode(TestDomain.Types.NamedNode, name: "")
        let whitespace = frame.createNode(TestDomain.Types.NamedNode, name: " \t\n\r")
        let underscores = frame.createNode(TestDomain.Types.NamedNode, name: "___")

        let world = try accept()

        for object in [empty, whitespace, underscores] {
            let entity = try #require(world.entity(object.objectID))
            #expect(entity.hasIssue(IssueIdentifier.emptyName))
            let name: NormalizedName? = entity.component()
            #expect(name == nil)
        }
    }

    @Test func ignoresObjectsWithoutNameTrait() throws {
        let object = frame.createNode(TestDomain.Types.TestNode)

        let world = try accept()

        let entity = try #require(world.entity(object.objectID))
        let name: NormalizedName? = entity.component()
        #expect(name == nil)
        #expect(!entity.hasIssues)
    }
}
