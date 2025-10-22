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
        self.loader = DesignLoader(metamodel: TestMetamodel)
    }

    // MARK: - Default Structural Type

    @Test("Default structural types")
    func defaultStructuralTypeUnstructured() async throws {
        let resolvedUnstr = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestPlain", // has .unstructured structural type
            structuralType: nil // not specified - should use default
        )

        let snapshotUnstr = try loader.createSnapshot(resolvedUnstr, children: nil)

        #expect(snapshotUnstr.structure == .unstructured)
        #expect(snapshotUnstr.snapshotID == ObjectSnapshotID(100))
        #expect(snapshotUnstr.objectID == ObjectID(10))
        #expect(snapshotUnstr.type.name == "TestPlain")

        let resolvedNode = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode", // has .node structural type
            structuralType: nil // not specified - should use default
        )

        let snapshotNode = try loader.createSnapshot(resolvedNode, children: nil)

        #expect(snapshotNode.structure == .node)
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
            _ = try loader.createSnapshot(resolved, children: nil)
        }
    }

    // MARK: - Explicit Structural Type Matching

    @Test("Explicit structure type match")
    func explicitUnstructuredMatches() async throws {
        let resolvedUnstr = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestPlain",
            structuralType: .unstructured // explicitly specified
        )

        let snapshotUnstr = try loader.createSnapshot(resolvedUnstr, children: nil)

        #expect(snapshotUnstr.structure == .unstructured)

        let resolvedNode = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode",
            structuralType: .node // explicitly specified
        )

        let snapshotNode = try loader.createSnapshot(resolvedNode, children: nil)

        #expect(snapshotNode.structure == .node)

        let resolvedEdge = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge, // explicitly specified
            structureReferences: [ObjectID(10), ObjectID(20)]
        )

        let snapshotEdge = try loader.createSnapshot(resolvedEdge, children: nil)

        #expect(snapshotEdge.structure == .edge(ObjectID(10), ObjectID(20)))
    }

    // MARK: - Structural Type Mismatch

    @Test("Structural type mismatch")
    func mismatchUnstructuredAsNode() async throws {
        let resolvedNode = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestPlain", // .unstructured type
            structuralType: .node // trying to use as node
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.unstructured)) {
            _ = try loader.createSnapshot(resolvedNode, children: nil)
        }

        let resolvedUnstr = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode", // .node type
            structuralType: .unstructured // trying to use as unstructured
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.node)) {
            _ = try loader.createSnapshot(resolvedUnstr, children: nil)
        }

        let resolvedEdgeType = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge", // .edge type
            structuralType: .node // trying to use as node
        )

        #expect(throws: DesignLoaderError.ItemError.structuralTypeMismatch(.edge)) {
            _ = try loader.createSnapshot(resolvedEdgeType, children: nil)
        }
    }

    // MARK: - Invalid Structure Type

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
            _ = try loader.createSnapshot(resolvedEmpty, children: nil)
        }

        let resolvedOne = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge,
            structureReferences: [ObjectID(10)] // should have exactly 2
        )

        #expect(throws: DesignLoaderError.ItemError.invalidStructuralType) {
            _ = try loader.createSnapshot(resolvedOne, children: nil)
        }

        let resolvedTooMany = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(300),
            objectID: ObjectID(30),
            typeName: "TestEdge",
            structuralType: .edge,
            structureReferences: [ObjectID(10), ObjectID(20), ObjectID(30)] // should have exactly 2
        )

        #expect(throws: DesignLoaderError.ItemError.invalidStructuralType) {
            _ = try loader.createSnapshot(resolvedTooMany, children: nil)
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
            _ = try loader.createSnapshot(resolved, children: nil)
        }
    }

    // MARK: - Attributes and Children

    @Test("Snapshot with attributes")
    func snapshotWithAttributes() async throws {
        let resolved = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestPlain",
            structuralType: .unstructured,
            attributes: ["name": Variant("test"), "value": Variant(42)]
        )

        let snapshot = try loader.createSnapshot(resolved, children: nil)

        #expect(snapshot.attributes["name"] == Variant("test"))
        #expect(snapshot.attributes["value"] == Variant(42))
    }

    @Test("Snapshot with children")
    func snapshotWithChildren() async throws {
        let resolved = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(100),
            objectID: ObjectID(10),
            typeName: "TestNode",
            structuralType: .node,
        )

        let children = [ObjectID(20), ObjectID(30), ObjectID(40)]
        let snapshot = try loader.createSnapshot(resolved, children: children)

        #expect(Array(snapshot.children) == [ObjectID(20), ObjectID(30), ObjectID(40)])
    }

    @Test("Snapshot with parent")
    func snapshotWithParent() async throws {
        let resolved = DesignLoader.ResolvedObjectSnapshot(
            snapshotID: ObjectSnapshotID(200),
            objectID: ObjectID(20),
            typeName: "TestNode",
            structuralType: .node,
            parent: ObjectID(10)
        )

        let snapshot = try loader.createSnapshot(resolved, children: nil)

        #expect(snapshot.parent == ObjectID(10))
    }
}
