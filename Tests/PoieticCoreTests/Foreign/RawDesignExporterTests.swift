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

        let first = DesignFrame(design: design, id: 1000, snapshots: [])
        design._unsafeInsert(first)
        let trans = design.createFrame(deriving: first)
        let unstructured = DesignObject(id: 10, snapshotID: 100, type: TestType)
        let node1 = DesignObject(id: 11, snapshotID: 101, type: TestNodeType)
        let node2 = DesignObject(id: 12, snapshotID: 102, type: TestNodeType)
        let edge = DesignObject(id: 13, snapshotID: 103, type: TestEdgeType, structure: .edge(node1.id, node2.id))
        let frame = DesignFrame(design: design, id: 1001,
                                snapshots: [unstructured, node1, node2, edge ])
        design._unsafeInsert(frame)
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
        #expect(currentFrameRef.id == .id(frame.id))

        #expect(raw.systemLists.count == 1)
        let undoRefList: RawNamedList = try #require(raw.systemLists.first { $0.name == "undo"} )
        #expect(undoRefList.itemType == "frame")
        #expect(undoRefList.ids == [.id(first.id)])
        
        let rawFrame = try #require(raw.frames.first {$0.id == .id(frame.id)})
        #expect(rawFrame.snapshots.count == 4)
        #expect(rawFrame.snapshots == [.id(unstructured.snapshotID),
                                       .id(node1.snapshotID),
                                       .id(node2.snapshotID),
                                       .id(edge.snapshotID)])
    }
    
    @Test func extractPruning() async throws {
        let design = Design(metamodel: TestMetamodel)
        let trans = design.createFrame()
        let parent = DesignObject(id: 10, snapshotID: 100, type: TestType, children: [ObjectID(11)])
        let child = DesignObject(id: 11, snapshotID: 101, type: TestType, parent: ObjectID(10))
        let node1 = DesignObject(id: 12, snapshotID: 102, type: TestNodeType)
        let node2 = DesignObject(id: 13, snapshotID: 103, type: TestNodeType)
        let edge = DesignObject(id: 14, snapshotID: 104, type: TestEdgeType, structure: .edge(node1.id, node2.id))
        let frame = DesignFrame(design: design, id: 1001,
                                snapshots: [parent, child, node1, node2, edge ])
        design._unsafeInsert(frame)

        let extractor = DesignExtractor()

        let extract1 = extractor.extractPruning(snapshots: [node1.id, node2.id, edge.id], frame: frame)
        #expect(extract1.map { $0.id } == [.id(node1.id), .id(node2.id), .id(edge.id)])

        let extract2 = extractor.extractPruning(snapshots: [node1.id, edge.id], frame: frame)
        #expect(extract2.map { $0.id } == [.id(node1.id)])

        let extract3 = extractor.extractPruning(snapshots: [edge.id], frame: frame)
        #expect(extract3.map { $0.id } == [])

        // Parent-child
        let extract4 = extractor.extractPruning(snapshots: [parent.id, child.id], frame: frame)
        #expect(extract4.map { $0.parent } == [nil, .id(parent.id)])

        let extract5 = extractor.extractPruning(snapshots: [child.id], frame: frame)
        #expect(extract5.map { $0.parent } == [nil])

    }

}
