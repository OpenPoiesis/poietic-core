//
//  DesignLoaderLoadIntoTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 22/10/2025.
//

import Testing
@testable import PoieticCore

@Suite("Design Loader: load(into:)")
struct DesignLoaderLoadIntoTests {
    let loader: DesignLoader
    let design: Design

    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
        self.design = Design(metamodel: TestMetamodel)
    }

    // MARK: - Core Functionality Tests

    @Test("Load into transient frame marks it as changed")
    func loadIntoHasChanges() async throws {
        let trans = design.createFrame()
        let raw = RawSnapshot(typeName: "TestPlain")
        try loader.load([raw], into: trans)

        #expect(trans.snapshots.count == 1)
        #expect(trans.hasChanges)
    }

    @Test("Loading same snapshot multiple times creates different objects")
    func loadIntoMultipleTimes() async throws {
        let trans = design.createFrame()
        let raw = RawSnapshot(typeName: "TestPlain")

        // Load the same snapshot twice
        try loader.load([raw], into: trans)
        try loader.load([raw], into: trans)

        #expect(trans.snapshots.count == 2)

        // Each load should create different snapshot and object IDs
        #expect(trans.snapshots[0].snapshotID != trans.snapshots[1].snapshotID)
        #expect(trans.snapshots[0].objectID != trans.snapshots[1].objectID)
    }

    @Test("Edge references are resolved correctly")
    func loadIntoReferences() async throws {
        let trans = design.createFrame()
        let node1 = RawSnapshot(typeName: "TestNode", id: .int(10))
        let node2 = RawSnapshot(typeName: "TestNode", id: .int(20))
        let edge = RawSnapshot(
            typeName: "TestEdge",
            id: .int(30),
            structure: RawStructure("edge", references: [.int(10), .int(20)])
        )

        try loader.load([node1, node2, edge], into: trans)

        #expect(trans.snapshots.count == 3)

        let createdEdge = try #require(trans.snapshots.first(where: { $0.structure.type == .edge }))

        if case let .edge(origin, target) = createdEdge.structure {
            #expect(origin != target)
            #expect(trans.contains(origin))
            #expect(trans.contains(target))
        } else {
            Issue.record("Expected edge structure")
        }
    }

    @Test("Load RawDesign with no current frame and no frames")
    func importIntoNoCurrentID() async throws {
        let trans = design.createFrame()
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain")
            ]
        )
        try loader.load(rawDesign, into: trans)

        #expect(trans.snapshots.count == 1)
        #expect(trans.hasChanges)
    }

    @Test("Load from current frame in multi-frame RawDesign")
    func importFromCurrentFrame() async throws {
        let trans = design.createFrame()
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(10)),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(20)),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(30)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(10)]),
                RawFrame(id: .int(1001), snapshots: [.int(10), .int(20)]),
            ],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(1000))
            ]
        )
        try loader.load(rawDesign, into: trans)

        // Should only load snapshots from current frame (1000), which has only snapshot 10
        #expect(trans.snapshots.count == 1)
    }

    // MARK: - Error Cases

    @Test("Error: broken edge reference")
    func loadIntoBrokenReference() async throws {
        let trans = design.createFrame()
        let edge = RawSnapshot(
            typeName: "TestEdge",
            id: .int(30),
            structure: RawStructure("edge", references: [.int(10), .int(20)])
        )

        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .unknownID(.int(10)))) {
            try loader.load([edge], into: trans)
        }
    }

    @Test("Error: duplicate object ID")
    func loadIntoDuplicsteObjectID() async throws {
        let trans = design.createFrame()
        let rawSnapshots: [RawSnapshot] = [
            RawSnapshot(typeName: "TestNode", id: .string("consumption_inner")),
            RawSnapshot(typeName: "TestNode", id: .string("consumption_inner")),
        ]

        #expect(throws: DesignLoaderError.item(.objectSnapshots, 1, .duplicateObject(1))) {
            try loader.load(rawSnapshots, into: trans)
        }
    }

    @Test("Error: invalid current frame ID in RawDesign")
    func importIntoInvalidCurrentID() async throws {
        let trans = design.createFrame()
        let rawDesign = RawDesign(
            snapshots: [],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(99))
            ]
        )

        #expect(throws: DesignLoaderError.design(.unknownFrameID(.int(99)))) {
            try loader.load(rawDesign, into: trans)
        }
    }

    @Test("Error: multiple frames without current frame")
    func importIntoNoCurrentIDWithMultipleFrames() async throws {
        let trans = design.createFrame()
        let rawDesign = RawDesign(
            snapshots: [],
            frames: [
                RawFrame(id: .int(1000), snapshots: []),
                RawFrame(id: .int(1001), snapshots: [])
            ]
        )

        #expect(throws: DesignLoaderError.design(.missingCurrentFrame)) {
            try loader.load(rawDesign, into: trans)
        }
    }

    // MARK: - Identity Strategy Tests

    @Test("Identity strategy: createNew ignores provided IDs")
    func loadCreateIdentity() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestNode", snapshotID: .int(100), id: .int(10)),
            ]
        )
        let trans = design.createFrame()
        try loader.load(rawDesign.snapshots, into: trans, identityStrategy: .createNew)
        try design.accept(trans)
        #expect(design.identityManager.reserved.isEmpty)

        let snapshot = try #require(design.objectSnapshots.first)
        #expect(snapshot.snapshotID != ObjectSnapshotID(100))
        #expect(snapshot.objectID != ObjectID(10))
    }

    @Test("Identity strategy: preserveOrCreate on first load preserves, on second creates new")
    func loadTwiceWithPreserveOrCreate() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11), attributes: ["name": "node"]),
                RawSnapshot(typeName: "TestEdge", snapshotID: .int(102), id: .int(12),
                            structure: RawStructure(origin: .int(11), target: .int(11)), attributes: ["name": "edge"]),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(103), id: .int(13), parent: .int(11), attributes: ["name": "child"]),
            ]
        )
        let trans = design.createFrame()
        try loader.load(rawDesign.snapshots, into: trans, identityStrategy: .preserveOrCreate)
        let frame = try design.accept(trans)
        #expect(design.identityManager.reserved.isEmpty)

        let node1 = try #require(frame.first(where: { $0["name"] == "node"}))
        let edge1 = try #require(frame.first(where: { $0["name"] == "edge"}))
        let child1 = try #require(frame.first(where: { $0["name"] == "child"}))
        #expect(edge1.structure == .edge(node1.objectID, node1.objectID))
        #expect(child1.parent == node1.objectID)
        #expect(Array(node1.children) == [child1.objectID])

        // Load same raw snapshots again into a derived frame
        // The IDs already exist in the target frame, so .preserveOrCreate should create new IDs
        let trans2 = design.createFrame(deriving: frame)
        try loader.load(rawDesign.snapshots, into: trans2, identityStrategy: .preserveOrCreate)

        let frame2 = try design.accept(trans2)
        let node2 = try #require(frame2.first(where: { $0["name"] == "node" && $0.objectID != node1.objectID }))
        let edge2 = try #require(frame2.first(where: { $0["name"] == "edge" && $0.objectID != edge1.objectID }))
        let child2 = try #require(frame2.first(where: { $0["name"] == "child" && $0.objectID != child1.objectID }))

        #expect(edge2.structure == .edge(node2.objectID, node2.objectID))
        #expect(child2.parent == node2.objectID)
        #expect(Array(node2.children) == [child2.objectID])
    }

    @Test("Simulated copy-paste workflow")
    func simulatedPaste() async throws {
        let trans1 = design.createFrame()
        let a = trans1.createNode(TestNodeType, attributes: ["name": "a"])
        let b = trans1.createNode(TestNodeType, attributes: ["name": "b"])
        let edge = trans1.createEdge(TestEdgeType, origin: a.objectID, target: b.objectID, attributes: ["name": "edge"])
        let frame1 = try design.accept(trans1)

        // Copy
        let extractor = DesignExtractor()
        let extract = extractor.extractPruning(objects: [a.objectID, b.objectID, edge.objectID], frame: frame1)
        let rawDesign = RawDesign(metamodelName: design.metamodel.name,
                                  metamodelVersion: design.metamodel.version,
                                  snapshots: extract)
        // Paste
        let trans2 = design.createFrame(deriving: frame1)
        try loader.load(rawDesign.snapshots,
                        into: trans2,
                        identityStrategy: .preserveOrCreate)
        let frame2 = try design.accept(trans2)
        // Paste the same thing again
        let trans3 = design.createFrame(deriving: frame2)
        try loader.load(rawDesign.snapshots,
                        into: trans3,
                        identityStrategy: .preserveOrCreate)

        let frame3 = try design.accept(trans3)

        #expect(frame3.filter { $0["name"] == "a" }.count == 3)
        #expect(frame3.filter { $0["name"] == "b" }.count == 3)
        #expect(frame3.filter { $0["name"] == "edge" }.count == 3)
    }
}
