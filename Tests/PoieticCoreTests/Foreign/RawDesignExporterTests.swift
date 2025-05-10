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
        let exporter = RawDesignExporter()
        let raw = exporter.export(design)
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

        
        let exporter = RawDesignExporter()
        let raw = exporter.export(design)

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

}
