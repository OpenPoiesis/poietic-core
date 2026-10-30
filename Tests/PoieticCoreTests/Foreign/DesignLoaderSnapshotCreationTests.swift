//
//  DesignLoaderSnapshotCreationTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 22/10/2025.
//

import Testing
@testable import PoieticCore

@Suite("Design Loader: snapshot creation")
struct DesignLoaderSnapshotCreationTests {
    let loader: DesignLoader

    init() {
        self.loader = DesignLoader(metamodel: TestDomain.TestMetamodel)
    }

    // MARK: - Default Structural Type

    @Test("Default structural types")
    func defaultStructuralTypeUnstructured() async throws {
        let resolvedUnstr = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestUnstructured", // has .unstructured structural type
            structuralType: nil // not specified - should use default
        )

        let snapshotUnstr = try loader.createSnapshot(resolvedUnstr)

        #expect(snapshotUnstr.topology == .unstructured)
        #expect(snapshotUnstr.snapshotID == ObjectSnapshotID(100))
        #expect(snapshotUnstr.objectID == ObjectID(10))
        #expect(snapshotUnstr.type.name == "TestUnstructured")

        let resolvedNode = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode", // has .node structural type
            structuralType: nil // not specified - should use default
        )

        let snapshotNode = try loader.createSnapshot(resolvedNode)

        #expect(snapshotNode.topology == .node)
    }

    @Test("Default structural type - edge not allowed")
    func defaultStructuralTypeEdgeNotAllowed() async throws {
        // Edge type CANNOT use default - must be explicitly specified
        let resolved = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge", // has .edge structural type
            structuralType: nil // not specified
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.edge)) {
            _ = try loader.createSnapshot(resolved)
        }
    }

    // MARK: - Explicit Structural Type Matching

    @Test("Explicit topology type match")
    func explicitUnstructuredMatches() async throws {
        let resolvedUnstr = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestUnstructured",
            structuralType: .unstructured // explicitly specified
        )

        let snapshotUnstr = try loader.createSnapshot(resolvedUnstr)

        #expect(snapshotUnstr.topology == .unstructured)

        let resolvedNode = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode",
            structuralType: .node // explicitly specified
        )

        let snapshotNode = try loader.createSnapshot(resolvedNode)

        #expect(snapshotNode.topology == .node)

        let resolvedEdge = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge, // explicitly specified
            structureReferences: [ObjectID(10), ObjectID(20)]
        )

        let snapshotEdge = try loader.createSnapshot(resolvedEdge)

        #expect(snapshotEdge.topology == .edge(ObjectID(10), ObjectID(20)))
    }

    // MARK: - Structural Type Mismatch

    @Test("Structural type mismatch")
    func mismatchUnstructuredAsNode() async throws {
        let resolvedNode = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestUnstructured", // .unstructured type
            structuralType: .node // trying to use as node
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.unstructured)) {
            _ = try loader.createSnapshot(resolvedNode)
        }

        let resolvedUnstr = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode", // .node type
            structuralType: .unstructured // trying to use as unstructured
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.node)) {
            _ = try loader.createSnapshot(resolvedUnstr)
        }

        let resolvedEdgeType = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge", // .edge type
            structuralType: .node // trying to use as node
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.edge)) {
            _ = try loader.createSnapshot(resolvedEdgeType)
        }
    }

    // MARK: - Invalid Topology Type

    @Test("Invalid edge references")
    func invalidEdgeNoReferences() async throws {
        let resolvedEmpty = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge,
            structureReferences: [] // should have exactly 2
        )

        #expect(throws: DesignLoaderError.ItemError.invalidStructuralType) {
            _ = try loader.createSnapshot(resolvedEmpty)
        }

        let resolvedOne = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge,
            structureReferences: [ObjectID(10)] // should have exactly 2
        )

        #expect(throws: DesignLoaderError.ItemError.invalidStructuralType) {
            _ = try loader.createSnapshot(resolvedOne)
        }

        let resolvedTooMany = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge,
            structureReferences: [ObjectID(10), ObjectID(20), ObjectID(30)] // should have exactly 2
        )

        #expect(throws: DesignLoaderError.ItemError.invalidStructuralType) {
            _ = try loader.createSnapshot(resolvedTooMany)
        }
    }

    // MARK: - Unknown Object Type

    @Test("Unknown object type")
    func unknownObjectType() async throws {
        let resolved = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(999),
            objectID: ObjectID(99),
            typeName: "NonExistentType", // doesn't exist in metamodel
            structuralType: .unstructured,
        )

        #expect(throws: DesignLoaderError.ItemError.unknownObjectType("NonExistentType")) {
            _ = try loader.createSnapshot(resolved)
        }
    }

    // MARK: - Attributes and Children

    @Test("Snapshot with attributes")
    func snapshotWithAttributes() async throws {
        let resolved = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestUnstructured",
            structuralType: .unstructured,
            attributes: ["name": Variant("test"), "value": Variant(42)]
        )

        let snapshot = try loader.createSnapshot(resolved)

        #expect(snapshot.attributes["name"] == Variant("test"))
        #expect(snapshot.attributes["value"] == Variant(42))
    }
}
