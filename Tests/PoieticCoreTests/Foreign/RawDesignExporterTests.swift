//
//  RawDesignExporterTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/05/2025.
//

import Testing
@testable import PoieticCore

struct RawDesignExpoerterTest {
    @Test func exportEmptyDesign() async throws {
        let design = Design()
        let exporter = DesignExtractor()
        let raw = exporter.extract(design)
        #expect(raw.metamodelName == nil)
        #expect(raw.metamodelVersion == nil)
        #expect(raw.snapshots.isEmpty)
        #expect(raw.frames.isEmpty)
        #expect(raw.userReferences.isEmpty)
        #expect(raw.userLists.isEmpty)
        #expect(raw.systemReferences.isEmpty)
        #expect(raw.systemLists.isEmpty)
    }
    @Test func exportSomeDesign() async throws {
        let design = Design(metamodel: TestMetamodel)

        let first = DesignSnapshot(design: design, id: 1000, snapshots: [])
        design.unsafeInsert(first)
        let _ = design.createFrame(deriving: first)
        let unstructured = ObjectSnapshot(type: TestType, snapshotID: 100, objectID: 10)
        let node1 = ObjectSnapshot(type: TestNodeType, snapshotID: 101, objectID: 11)
        let node2 = ObjectSnapshot(type: TestNodeType, snapshotID: 102, objectID: 12)
        let edge = ObjectSnapshot(type: TestEdgeType, snapshotID: 103, objectID: 13, structure: .edge(node1.objectID, node2.objectID))
        let frame = DesignSnapshot(design: design, id: 1001,
                                snapshots: [unstructured, node1, node2, edge ])
        design.unsafeInsert(frame)
        design.currentFrameID = frame.id
        design.undoableFrames = [first.id]

        
        let exporter = DesignExtractor()
        let raw = exporter.extract(design)

        #expect(raw.metamodelName == TestMetamodel.name)
        #expect(raw.metamodelVersion == nil)
        #expect(raw.snapshots.count == 4)
        #expect(raw.frames.count == 2)
        #expect(raw.userReferences.isEmpty)
        #expect(raw.userLists.isEmpty)

        #expect(raw.systemReferences.count == 1)
        let currentFrameRef = try #require(raw.systemReferences.first)
        #expect(currentFrameRef.name == "current_frame")
        #expect(currentFrameRef.type == "frame")
        #expect(currentFrameRef.id == .id(frame.id.rawValue))

        #expect(raw.systemLists.count == 1)
        let undoRefList: RawNamedList = try #require(raw.systemLists.first { $0.name == "undo"} )
        #expect(undoRefList.itemType == "frame")
        #expect(undoRefList.ids == [.id(first.id.rawValue)])
        
        let rawFrame = try #require(raw.frames.first {$0.id == .id(frame.id.rawValue)})
        #expect(rawFrame.snapshots.count == 4)
        #expect(rawFrame.snapshots == [.id(unstructured.snapshotID.rawValue),
                                       .id(node1.snapshotID.rawValue),
                                       .id(node2.snapshotID.rawValue),
                                       .id(edge.snapshotID.rawValue)])
    }
    
    @Test func extractPruning() async throws {
        let design = Design(metamodel: TestMetamodel)
        let parent = ObjectSnapshot(type: TestType, snapshotID: 100, objectID: 10, children: [ObjectID(11)])
        let child = ObjectSnapshot(type: TestType, snapshotID: 101, objectID: 11, parent: ObjectID(10))
        let node1 = ObjectSnapshot(type: TestNodeType, snapshotID: 102, objectID: 12)
        let node2 = ObjectSnapshot(type: TestNodeType, snapshotID: 103, objectID: 13)
        let edge = ObjectSnapshot(type: TestEdgeType, snapshotID: 104, objectID: 14, structure: .edge(node1.objectID, node2.objectID))
        let frame = DesignSnapshot(design: design, id: 1001,
                                snapshots: [parent, child, node1, node2, edge ])
        design.unsafeInsert(frame)

        let extractor = DesignExtractor()

        let extract1 = extractor.extractPruning(objects: [node1.objectID, node2.objectID, edge.objectID], frame: frame)
        #expect(extract1.map { $0.objectID } == [.id(node1.objectID.rawValue),
                                                 .id(node2.objectID.rawValue),
                                                 .id(edge.objectID.rawValue)])

        let extract2 = extractor.extractPruning(objects: [node1.objectID,
                                                          edge.objectID], frame: frame)
        #expect(extract2.map { $0.objectID } == [.id(node1.objectID.rawValue)])

        let extract3 = extractor.extractPruning(objects: [edge.objectID], frame: frame)
        #expect(extract3.map { $0.objectID } == [])

        // Parent-child
        let extract4 = extractor.extractPruning(objects: [parent.objectID, child.objectID], frame: frame)
        #expect(extract4.map { $0.parent } == [nil, .id(parent.objectID.rawValue)])

        let extract5 = extractor.extractPruning(objects: [child.objectID], frame: frame)
        #expect(extract5.map { $0.parent } == [nil])

    }

}
