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
        #expect(raw.planes.isEmpty)
        #expect(raw.userReferences.isEmpty)
        #expect(raw.userLists.isEmpty)
        #expect(raw.systemReferences.isEmpty)
        #expect(raw.systemLists.isEmpty)
    }
    @Test func exportSomeDesign() async throws {
        let design = Design(metamodel: TestMetamodel)

        let first = DesignPlane(design: design, id: 1000, snapshots: [])
        design.unsafeInsert(first)
        let _ = design.createPlane(deriving: first)
        let unstructured = ObjectSnapshot(type: TestType, snapshotID: 100, objectID: 10)
        let node1 = ObjectSnapshot(type: TestNodeType, snapshotID: 101, objectID: 11)
        let node2 = ObjectSnapshot(type: TestNodeType, snapshotID: 102, objectID: 12)
        let edge = ObjectSnapshot(type: TestEdgeType, snapshotID: 103, objectID: 13, topology: .edge(node1.objectID, node2.objectID))
        let frame = DesignPlane(design: design, id: 1001,
                                snapshots: [unstructured, node1, node2, edge ])
        design.unsafeInsert(frame)
        design.currentPlaneID = frame.id
        design.undoList = [first.id]

        
        let exporter = DesignExtractor()
        let raw: RawDesign = exporter.extract(design)

        #expect(raw.metamodelName == TestMetamodel.name)
        #expect(raw.metamodelVersion == nil)
        #expect(raw.snapshots.count == 4)
        #expect(raw.planes.count == 2)
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
        
        let rawPlane: RawPlane = try #require(raw.planes.first {$0.id == .id(frame.id)})
        #expect(rawPlane.snapshots.count == 4)
        #expect(rawPlane.snapshots == [.id(unstructured.snapshotID),
                                       .id(node1.snapshotID),
                                       .id(node2.snapshotID),
                                       .id(edge.snapshotID)])
    }
    
    @Test func extractPruning() async throws {
        let design = Design(metamodel: TestMetamodel)
        let parent = ObjectSnapshot(type: TestType, snapshotID: 100, objectID: 10, children: [ObjectID(11)])
        let child = ObjectSnapshot(type: TestType, snapshotID: 101, objectID: 11, parent: ObjectID(10))
        let node1 = ObjectSnapshot(type: TestNodeType, snapshotID: 102, objectID: 12)
        let node2 = ObjectSnapshot(type: TestNodeType, snapshotID: 103, objectID: 13)
        let edge = ObjectSnapshot(type: TestEdgeType, snapshotID: 104, objectID: 14, topology: .edge(node1.objectID, node2.objectID))
        let plane = DesignPlane(design: design, id: 1001,
                                snapshots: [parent, child, node1, node2, edge ])
        design.unsafeInsert(plane)

        let extractor = DesignExtractor()

        let extract1: [RawSnapshot] = extractor.extractPruning(objects: [node1.objectID, node2.objectID, edge.objectID], plane: plane)
        #expect(extract1.map { $0.objectID } == [.id(node1.objectID),
                                                 .id(node2.objectID),
                                                 .id(edge.objectID)])

        let extract2: [RawSnapshot] = extractor.extractPruning(objects: [node1.objectID,
                                                          edge.objectID], plane: plane)
        #expect(extract2.map { $0.objectID } == [.id(node1.objectID)])

        let extract3: [RawSnapshot] = extractor.extractPruning(objects: [edge.objectID], plane: plane)
        #expect(extract3.map { $0.objectID } == [])

        // Parent-child
        let extract4: [RawSnapshot] = extractor.extractPruning(objects: [parent.objectID, child.objectID], plane: plane)
        #expect(extract4.map { $0.parent } == [nil, .id(parent.objectID)])

        let extract5: [RawSnapshot] = extractor.extractPruning(objects: [child.objectID], plane: plane)
        #expect(extract5.map { $0.parent } == [nil])

    }

}
