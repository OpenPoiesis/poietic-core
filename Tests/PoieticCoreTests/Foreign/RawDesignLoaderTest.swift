//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//

// TODO: Test createFrame when ID is reserved
// TODO: Test create object when both IDs are reserved
// TODO: Validate undo/redo is frame list
// TODO: Validate current_frame is frame

// Upgrade rules:
// 1. use structural type based on node type

import Testing
@testable import PoieticCore

struct RawDesignLoaderTest {
    let design: Design
    let loader: DesignLoader
    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
        self.design = Design(metamodel: TestMetamodel)
        
    }
    
    @Test func loadNoID() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain")
            ]
        )
        let design = try loader.load(raw)
        #expect(design.snapshots.isEmpty == true)
    }
    @Test func loadWithSnapshotID() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: RawObjectID.int(1))
            ],
            frames: [
                RawFrame(snapshots: [.int(1)])
            ]
        )
        let design = try loader.load(raw)
        let object = try #require(design.snapshots.first)
        #expect(object.snapshotID == ObjectID(1))
    }
    @Test func structuralType() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10), structure: RawStructure("unstructured")),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11), structure: RawStructure("node")),
            ],
            frames: [
                RawFrame(snapshots: [.int(100), .int(101)])
            ]
        )
        let design = try loader.load(raw)
        let o1 = try #require(design.snapshot(ObjectID(100)))
        #expect(o1.objectID == ObjectID(10))
        #expect(o1.snapshotID == ObjectID(100))
        #expect(o1.structure == .unstructured)
        
        let o2 = try #require(design.snapshot(ObjectID(101)))
        #expect(o2.objectID == ObjectID(11))
        #expect(o2.snapshotID == ObjectID(101))
        #expect(o2.structure == .node)
    }
    
    // TODO: [WIP] [IMPORTANT] Fix parent-child hierarchy
    
    //    @Test
    func loadEverything() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11), structure: RawStructure("node")),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(102), id: .int(12), structure: RawStructure("node")),
                RawSnapshot(typeName: "TestEdge", snapshotID: .int(103), id: .int(13),
                            structure: RawStructure("edge", references: [.int(11), .int(12)])),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(104), id: .int(14), parent: .int(10)),
            ],
            frames: [
                RawFrame(snapshots: [.int(100), .int(101), .int(102), .int(103), .int(104)])
            ]
        )
        let design = try loader.load(raw)
        let o0 = try #require(design.snapshot(ObjectID(100)))
        #expect(o0.objectID == ObjectID(10))
        #expect(o0.snapshotID == ObjectID(100))
        #expect(o0.structure == .unstructured)
        #expect(o0.parent == nil)
        #expect(o0.children == [ObjectID(14)])
        let o1 = try #require(design.snapshot(ObjectID(101)))
        #expect(o1.objectID == ObjectID(11))
        #expect(o1.snapshotID == ObjectID(101))
        #expect(o1.structure == .node)
        #expect(o0.parent == nil)
        #expect(o0.children.isEmpty == true)
        let o2 = try #require(design.snapshot(ObjectID(102)))
        #expect(o2.objectID == ObjectID(12))
        #expect(o2.snapshotID == ObjectID(102))
        #expect(o2.structure == .node)
        #expect(o0.parent == nil)
        #expect(o0.children.isEmpty == true)
        let o3 = try #require(design.snapshot(ObjectID(103)))
        #expect(o3.objectID == ObjectID(13))
        #expect(o3.snapshotID == ObjectID(103))
        #expect(o3.structure == .edge(ObjectID(11), ObjectID(12)))
        #expect(o0.parent == nil)
        #expect(o0.children.isEmpty == true)
        let o4 = try #require(design.snapshot(ObjectID(104)))
        #expect(o4.objectID == ObjectID(14))
        #expect(o4.snapshotID == ObjectID(104))
        #expect(o4.structure == .node)
        #expect(o4.parent == ObjectID(10))
        #expect(o4.children.isEmpty == true)
    }
    @Test func loadMissingObjectType() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: nil, snapshotID: RawObjectID.int(10)),
            ],
            frames: [
                RawFrame(snapshots: [.int(10)])
            ]
        )
        #expect(throws: DesignLoaderError.snapshotError(0, .missingObjectType)) {
            try loader.load(raw)
        }
    }
    @Test func loadUnknownObjectType() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "Unknown", snapshotID: RawObjectID.int(10)),
            ],
            frames: [
                RawFrame(snapshots: [.int(10)])
            ]
        )
        #expect(throws: DesignLoaderError.snapshotError(0, .unknownObjectType("Unknown"))) {
            try loader.load(raw)
        }
    }
    @Test func loadInvalidStructure() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestEdge", snapshotID: .int(10), structure: RawStructure("edge", references: [])),
            ],
            frames: [
                RawFrame(snapshots: [.int(10)])
            ]
        )
        #expect(throws: DesignLoaderError.snapshotError(0, .invalidStructuralType)) {
            try loader.load(raw)
        }
    }
    @Test func loadInvalidReferenceInStructure() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestEdge", snapshotID: .int(10), structure: RawStructure("edge", references: [.int(100), .int(200)])),
            ],
            frames: [
                RawFrame(snapshots: [.int(10)])
            ]
        )
        #expect(throws: DesignLoaderError.snapshotError(0, .unknownObjectID(.int(100)))) {
            try loader.load(raw)
        }
    }
    
    @Test func loadInvalidParentID() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestNode", snapshotID: .int(10), parent: .int(100)),
            ],
            frames: [
                RawFrame(snapshots: [.int(10)])
            ]
        )
        #expect(throws: DesignLoaderError.snapshotError(0, .unknownObjectID(.int(100)))) {
            try loader.load(raw)
        }
    }
    
    @Test func loadSystemReferences() async throws {
        let raw = RawDesign(
            snapshots: [
            ],
            frames: [
                RawFrame(id: .int(100), snapshots: []),
                RawFrame(id: .int(101), snapshots: []),
                RawFrame(id: .int(102), snapshots: []),
                RawFrame(id: .int(103), snapshots: []),
            ],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(100))
            ],
            systemLists: [
                RawNamedList("undo", itemType: "frame", ids: [.int(101), .int(102)]),
                RawNamedList("redo", itemType: "frame", ids: [.int(103)]),
            ]
        )
        let design = try loader.load(raw)
        #expect(design.currentFrameID == ObjectID(100))
        #expect(design.undoableFrames == [ObjectID(101), ObjectID(102)])
        #expect(design.redoableFrames == [ObjectID(103)])
    }
    
    
    // MARK: - Snapshot creation -
    
    @Test func createSnapshot() async throws {
        let reservation = IdentityReservation(design: self.design)
        let raw = RawSnapshot(typeName: "TestPlain")
        let raw2 = RawSnapshot(typeName: "TestPlain", attributes: ["number": 5])
        
        let snapshot = try loader.create(raw, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        
        #expect(snapshot.objectID == ObjectID(10))
        #expect(snapshot.snapshotID == ObjectID(100))
        #expect(snapshot.structure == .unstructured)
        #expect(snapshot.parent == nil)
        #expect(snapshot.attributes.isEmpty)
        
        let snapshot2 = try loader.create(raw2, id: ObjectID(11), snapshotID: ObjectID(101), reservation: reservation)
        #expect(snapshot2.objectID == ObjectID(11))
        #expect(snapshot2.snapshotID == ObjectID(101))
        #expect(snapshot2.attributes["number"] == Variant(5))
    }
    @Test func createSnapshotDefaultStructure() async throws {
        let reservation = IdentityReservation(design: self.design)
        let rawUnstructured = RawSnapshot(typeName: "TestPlain")
        let rawNode = RawSnapshot(typeName: "TestNode")
        
        let unstructured = try loader.create(rawUnstructured, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        #expect(unstructured.structure == .unstructured)
        
        let node = try loader.create(rawNode, id: ObjectID(11), snapshotID: ObjectID(101), reservation: reservation)
        #expect(node.structure == .node)
    }
    
    @Test func createSnapshotNoType() async throws {
        let reservation = IdentityReservation(design: self.design)
        let raw = RawSnapshot()
        
        #expect(throws: RawSnapshotError.missingObjectType) {
            _ = try loader.create(raw, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
            
        }
    }
    
    @Test func createSnapshotUnknownStructuralType() async throws {
        let reservation = IdentityReservation(design: self.design)
        let raw = RawSnapshot(typeName: "TestPlain", structure: RawStructure("INVALID"))
        
        #expect(throws: RawSnapshotError.invalidStructuralType) {
            _ = try loader.create(raw, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
    }
    
    @Test func createSnapshotStructureMismatch() async throws {
        let reservation = IdentityReservation(design: self.design)
        let rawU = RawSnapshot(typeName: "TestPlain", structure: RawStructure("node"))
        let rawN = RawSnapshot(typeName: "TestNode", structure: RawStructure("unstructured"))
        let rawE = RawSnapshot(typeName: "TestEdge", structure: RawStructure("node"))
        
        #expect(throws: RawSnapshotError.structuralTypeMismatch(.unstructured)) {
            _ = try loader.create(rawU, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
        #expect(throws: RawSnapshotError.structuralTypeMismatch(.node)) {
            _ = try loader.create(rawN, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
        #expect(throws: RawSnapshotError.structuralTypeMismatch(.edge)) {
            _ = try loader.create(rawE, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
    }
    
    @Test func createSnapshotInvalidEdgeType() async throws {
        var reservation = IdentityReservation(design: self.design)
        try reservation.reserve(snapshotID: .id(100), objectID: .id(10))
        
        let rawNoRefs = RawSnapshot(typeName: "TestEdge",
                                    structure: RawStructure("edge", references: []))
        let rawInvalidOrigin = RawSnapshot(typeName: "TestEdge",
                                           structure: RawStructure("edge", references: [.int(99), .int(10)]))
        let rawInvalidTarget = RawSnapshot(typeName: "TestEdge",
                                           structure: RawStructure("edge", references: [.int(10), .int(88)]))
        
        #expect(throws: RawSnapshotError.invalidStructuralType) {
            _ = try loader.create(rawNoRefs, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
        #expect(throws: RawSnapshotError.unknownObjectID(.int(99))) {
            _ = try loader.create(rawInvalidOrigin, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
        #expect(throws: RawSnapshotError.unknownObjectID(.int(88))) {
            _ = try loader.create(rawInvalidTarget, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
    }
    
    @Test func createSnapshotUnknownParent() async throws {
        let reservation = IdentityReservation(design: self.design)
        let raw = RawSnapshot(typeName: "TestPlain", parent: .int(99))
        
        #expect(throws: RawSnapshotError.unknownObjectID(.int(99))) {
            _ = try loader.create(raw, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        }
    }
    
    @Test func createSnapshotUseNameAsID() async throws {
        // Compatibility feature
        let loader = DesignLoader(metamodel: TestMetamodel, options: .useIDAsNameAttribute)
        
        let reservation = IdentityReservation(design: self.design)
        let rawNamed = RawSnapshot(typeName: "TestPlain", id: .string("thing"))
        let rawNotNamed = RawSnapshot(typeName: "TestPlain", id: .int(20))
        
        let snapshot = try loader.create(rawNamed, id: ObjectID(10), snapshotID: ObjectID(100), reservation: reservation)
        #expect(try snapshot.attributes["name"]?.stringValue() == "thing")
        let snapshotNot = try loader.create(rawNotNamed, id: ObjectID(20), snapshotID: ObjectID(101), reservation: reservation)
        #expect(try snapshotNot.attributes["name"] == nil)
    }
    
    // MARK: - Load Into -
    
    @Test func loadIntoHasChanges() async throws {
        let trans = design.createFrame()
        let raw = RawSnapshot(typeName: "TestPlain")
        try loader.load([raw], into: trans)
        
        #expect(trans.snapshots.count == 1)
        #expect(trans.hasChanges)
    }

    @Test func loadIntoMultipleTimes() async throws {
        let trans = design.createFrame()
        let raw = RawSnapshot(typeName: "TestPlain")
        try loader.load([raw], into: trans)
        try loader.load([raw], into: trans)

        try #require(trans.snapshots.count == 2)

        #expect(trans.snapshots[0].snapshotID != trans.snapshots[1].snapshotID)
        #expect(trans.snapshots[0].id != trans.snapshots[1].id)
    }
    @Test func loadIntoReferences() async throws {
        let trans = design.createFrame()
        let node1 = RawSnapshot(typeName: "TestNode", id: .int(10))
        let node2 = RawSnapshot(typeName: "TestNode", id: .int(20))
        let edge = RawSnapshot(typeName: "TestEdge", id: .int(30), structure: RawStructure(origin: .int(10), target: .int(20)))
        try loader.load([node1, node2, edge], into: trans)

        try #require(trans.snapshots.count == 3)
        let createdEdge = try #require(trans.snapshots.first (where: { $0.structure.type == .edge }))
        
        if case let .edge(origin, target) = createdEdge.structure {
            #expect(origin != target)
            #expect(trans.contains(origin))
            #expect(trans.contains(target))
        }
    }
    @Test func loadIntoBrokenReference() async throws {
        let trans = design.createFrame()
        let edge = RawSnapshot(typeName: "TestEdge", id: .int(30), structure: RawStructure(origin: .int(10), target: .int(20)))
        #expect(throws: DesignLoaderError.snapshotError(0, .unknownObjectID(.int(10)))) {
            try loader.load([edge], into: trans)
        }
    }
    @Test func importIntoNoCurrentID() async throws {
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

    @Test func importIntoInvalidCurrentID() async throws {
        let trans = design.createFrame()
        let rawDesign = RawDesign(
            snapshots: [
            ],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(99))
            ]
        )
        #expect(throws: DesignLoaderError.unknownFrameID(.int(99))) {
            try loader.load(rawDesign, into: trans)
        }
    }
    @Test func importIntoNoCurrentIDWithMultipleFrames() async throws {
        let trans = design.createFrame()
        let rawDesign = RawDesign(
            snapshots: [
            ],
            frames: [
                RawFrame(),
                RawFrame()
            ]
        )
        #expect(throws: DesignLoaderError.missingCurrentFrame) {
            try loader.load(rawDesign, into: trans)
        }
    }
    @Test func importFromCurrentFrame() async throws {
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
        #expect(trans.snapshots.count == 1)
    }

}

