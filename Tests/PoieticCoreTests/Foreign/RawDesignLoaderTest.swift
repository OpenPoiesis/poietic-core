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
        #expect(design.objectSnapshots.isEmpty == true)
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
        let object = try #require(design.objectSnapshots.first)
        #expect(object.snapshotID == ObjectSnapshotID(1))
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
        let o1 = try #require(design.snapshot(ObjectSnapshotID(100)))
        #expect(o1.objectID == ObjectID(10))
        #expect(o1.snapshotID == ObjectSnapshotID(100))
        #expect(o1.structure == .unstructured)
        
        let o2 = try #require(design.snapshot(ObjectSnapshotID(101)))
        #expect(o2.objectID == ObjectID(11))
        #expect(o2.snapshotID == ObjectSnapshotID(101))
        #expect(o2.structure == .node)
    }
    
    // TODO: [WIP] [IMPORTANT] Fix parent-child hierarchy
    /*
     Need: (frame -> (id -> parent id))
     Have: ()
     
     */
    @Test
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
        let o0 = try #require(design.snapshot(ObjectSnapshotID(100)))
        #expect(o0.objectID == ObjectID(10))
        #expect(o0.snapshotID == ObjectSnapshotID(100))
        #expect(o0.structure == .unstructured)
        #expect(o0.parent == nil)
        #expect(o0.children == [ObjectID(14)])
        let o1 = try #require(design.snapshot(ObjectSnapshotID(101)))
        #expect(o1.objectID == ObjectID(11))
        #expect(o1.snapshotID == ObjectSnapshotID(101))
        #expect(o1.structure == .node)
        #expect(o1.parent == nil)
        #expect(o1.children.isEmpty == true)
        let o2 = try #require(design.snapshot(ObjectSnapshotID(102)))
        #expect(o2.objectID == ObjectID(12))
        #expect(o2.snapshotID == ObjectSnapshotID(102))
        #expect(o2.structure == .node)
        #expect(o2.parent == nil)
        #expect(o2.children.isEmpty == true)
        let o3 = try #require(design.snapshot(ObjectSnapshotID(103)))
        #expect(o3.objectID == ObjectID(13))
        #expect(o3.snapshotID == ObjectSnapshotID(103))
        #expect(o3.structure == .edge(ObjectID(11), ObjectID(12)))
        #expect(o3.parent == nil)
        #expect(o3.children.isEmpty == true)
        let o4 = try #require(design.snapshot(ObjectSnapshotID(104)))
        #expect(o4.objectID == ObjectID(14))
        #expect(o4.snapshotID == ObjectSnapshotID(104))
        #expect(o4.structure == .unstructured)
        #expect(o4.parent == ObjectID(10))
        #expect(o4.children.isEmpty == true)
    }
    @Test func usecontexts() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(100)])
            ]
        )
        let design = try loader.load(raw)
        let frame = try #require(design.frames.first)
        let obj = try #require(design.snapshot(ObjectSnapshotID(100)))

        #expect(design.identityManager.isUsed(frame.id))
        #expect(design.identityManager.isUsed(obj.id))
        #expect(design.identityManager.isUsed(obj.objectID))
        #expect(design.identityManager.used.count == 3)
        #expect(design.identityManager.reserved.count == 0)
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
        #expect(design.currentFrameID == FrameID(100))
        #expect(design.undoList == [FrameID(101), FrameID(102)])
        #expect(design.redoList == [FrameID(103)])
    }
    
    
    // MARK: - Snapshot creation -
    
    @Test func createSnapshot() async throws {
        let context = LoadingContext(design: self.design)
        let raw = RawSnapshot(typeName: "TestPlain")
        let raw2 = RawSnapshot(typeName: "TestPlain", attributes: ["number": 5])
        
        let snapshot = try loader.create(raw, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        
        #expect(snapshot.objectID == ObjectID(10))
        #expect(snapshot.snapshotID == ObjectSnapshotID(100))
        #expect(snapshot.structure == .unstructured)
        #expect(snapshot.parent == nil)
        #expect(snapshot.attributes.isEmpty)
        
        let snapshot2 = try loader.create(raw2, snapshotID: ObjectSnapshotID(101), objectID: ObjectID(11), context: context)
        #expect(snapshot2.objectID == ObjectID(11))
        #expect(snapshot2.snapshotID == ObjectSnapshotID(101))
        #expect(snapshot2.attributes["number"] == Variant(5))
    }
    @Test func createSnapshotDefaultStructure() async throws {
        let context = LoadingContext(design: self.design)
        let rawUnstructured = RawSnapshot(typeName: "TestPlain")
        let rawNode = RawSnapshot(typeName: "TestNode")
        
        let unstructured = try loader.create(rawUnstructured, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        #expect(unstructured.structure == .unstructured)
        
        let node = try loader.create(rawNode, snapshotID: ObjectSnapshotID(101), objectID: ObjectID(11), context: context)
        #expect(node.structure == .node)
    }
    
    @Test func createSnapshotNoType() async throws {
        let context = LoadingContext(design: self.design)
        let raw = RawSnapshot()
        
        #expect(throws: RawSnapshotError.missingObjectType) {
            _ = try loader.create(raw, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
            
        }
    }
    
    @Test func createSnapshotUnknownStructuralType() async throws {
        let context = LoadingContext(design: self.design)
        let raw = RawSnapshot(typeName: "TestPlain", structure: RawStructure("INVALID"))
        
        #expect(throws: RawSnapshotError.invalidStructuralType) {
            _ = try loader.create(raw, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
    }
    
    @Test func createSnapshotStructureMismatch() async throws {
        let context = LoadingContext(design: self.design)
        let rawU = RawSnapshot(typeName: "TestPlain", structure: RawStructure("node"))
        let rawN = RawSnapshot(typeName: "TestNode", structure: RawStructure("unstructured"))
        let rawE = RawSnapshot(typeName: "TestEdge", structure: RawStructure("node"))
        
        #expect(throws: RawSnapshotError.structuralTypeMismatch(.unstructured)) {
            _ = try loader.create(rawU, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
        #expect(throws: RawSnapshotError.structuralTypeMismatch(.node)) {
            _ = try loader.create(rawN, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
        #expect(throws: RawSnapshotError.structuralTypeMismatch(.edge)) {
            _ = try loader.create(rawE, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
    }
    
    @Test func createSnapshotInvalidEdgeType() async throws {
        let context = LoadingContext(design: self.design)
        try context.reserve(snapshotID: .int(100), objectID: .int(10))
        let rawNoRefs = RawSnapshot(typeName: "TestEdge",
                                    structure: RawStructure("edge", references: []))
        let rawInvalidOrigin = RawSnapshot(typeName: "TestEdge",
                                           structure: RawStructure("edge", references: [.int(99), .int(10)]))
        let rawInvalidTarget = RawSnapshot(typeName: "TestEdge",
                                           structure: RawStructure("edge", references: [.int(10), .int(88)]))
        
        #expect(throws: RawSnapshotError.invalidStructuralType) {
            _ = try loader.create(rawNoRefs, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
        #expect(throws: RawSnapshotError.unknownObjectID(.int(99))) {
            _ = try loader.create(rawInvalidOrigin, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
        #expect(throws: RawSnapshotError.unknownObjectID(.int(88))) {
            _ = try loader.create(rawInvalidTarget, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        }
    }
    
    @Test func createSnapshotUnknownParent() async throws {
        let raw = RawSnapshot(typeName: "TestPlain", parent: .int(99))
        let trans = design.createFrame()
        
        #expect(throws: DesignLoaderError.snapshotError(0, .unknownObjectID(.int(99)))) {
            _ = try loader.load([raw], into: trans)
        }
    }
    
    @Test func createSnapshotUseNameAsID() async throws {
        // Compatibility feature
        let loader = DesignLoader(metamodel: TestMetamodel, options: .useIDAsNameAttribute)
        
        let context = LoadingContext(design: self.design)
        let rawNamed = RawSnapshot(typeName: "TestPlain", id: .string("thing"))
        let rawNotNamed = RawSnapshot(typeName: "TestPlain", id: .int(20))
        
        let snapshot = try loader.create(rawNamed, snapshotID: ObjectSnapshotID(100), objectID: ObjectID(10), context: context)
        #expect(try snapshot.attributes["name"]?.stringValue() == "thing")
        let snapshotNot = try loader.create(rawNotNamed, snapshotID: ObjectSnapshotID(101), objectID: ObjectID(20), context: context)
        #expect(snapshotNot.attributes["name"] == nil)
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

    @Test func duplicateID() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", id: .string("thing")),
                RawSnapshot(typeName: "TestPlain", id: .string("thing")),
            ],
        )
        let trans = design.createFrame()
        #expect(throws: DesignLoaderError.snapshotError(1, .duplicateID(.string("thing")))) {
            try loader.load(rawDesign.snapshots, into: trans)
        }
    }

    @Test func childrenMismatchNoneToSome() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(10), id: .int(100)),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(20), id: .int(200), parent: .int(100)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(10)]),
                RawFrame(id: .int(1001), snapshots: [.int(10), .int(20)]),
            ],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(1000))
            ]
        )
        #expect(throws: DesignLoaderError.frameError(1, .childrenMismatch(0))) {
            try loader.load(rawDesign)
        }
    }
    @Test func childrenMismatchSomeToNone() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(10), id: .int(100)),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(20), id: .int(200), parent: .int(100)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(10), .int(20)]),
                RawFrame(id: .int(1001), snapshots: [.int(10)]),
            ],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(1000))
            ]
        )
        #expect(throws: DesignLoaderError.frameError(1, .childrenMismatch(0))) {
            try loader.load(rawDesign)
        }
    }

    @Test func loadCreateIdentity() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestNode", snapshotID: .int(100), id: .int(10)),
            ],
        )
        let trans = design.createFrame()
        try loader.load(rawDesign.snapshots, into: trans, identityStrategy: .createNew)
        try design.accept(trans)
        #expect(design.identityManager.reserved.isEmpty)

        let snapshot = try #require(design.objectSnapshots.first)
        #expect(snapshot.snapshotID != ObjectSnapshotID(100))
        #expect(snapshot.objectID != ObjectID(10))
    }

    @Test func loadTwiceWithPreserveOrCreate() async throws {
        let rawDesign = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11), attributes: ["name": "node"]),
                RawSnapshot(typeName: "TestEdge", snapshotID: .int(102), id: .int(12),
                            structure: RawStructure(origin: .int(11), target: .int(11)), attributes: ["name": "edge"]),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(103), id: .int(13), parent: .int(11), attributes: ["name": "child"]),
            ],
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
        #expect(node1.children == [child1.objectID])

        let trans2 = design.createFrame(deriving: frame)
        try loader.load(rawDesign.snapshots, into: trans2, identityStrategy: .preserveOrCreate)

        let frame2 = try design.accept(trans2)
        let node2 = try #require(frame2.first(where: { $0["name"] == "node" && $0.objectID != node1.objectID }))
        let edge2 = try #require(frame2.first(where: { $0["name"] == "edge" && $0.objectID != edge1.objectID }))
        let child2 = try #require(frame2.first(where: { $0["name"] == "child" && $0.objectID != child1.objectID }))

        #expect(edge2.structure == .edge(node2.objectID, node2.objectID))
        #expect(child2.parent == node2.objectID)
        #expect(node2.children == [child2.objectID])
    }
    
    @Test func simulatedPaste() async throws {
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

