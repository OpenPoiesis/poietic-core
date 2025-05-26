//
//  JSONFrameReaderTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/05/2025.
//

import Foundation
import Testing
@testable import PoieticCore

// TODO: Invalid int reference -10
// TODO: Duplicate ID
// TODO: Test ID=name, attrs no name
// TODO: Test ID=name, attrs have name -> keep attrs name, not ID name

@Suite struct JSONFrameReaderTests {
    
    let design: Design
    let frame: TransientFrame
    let reader: JSONDesignReader
    
    init() throws {
        design = Design(metamodel: TestMetamodel)
        frame = design.createFrame()
//        reader = JSONDesignReader()
        reader = JSONDesignReader(variantCoding: .dictionaryWithFallback)
    }
   
    @Test func notADict() throws {
        let data = "[]".data(using:.utf8)!
        
        #expect(throws: RawDesignReaderError.typeMismatch("dictionary", [])) {
            try reader.read(data: data)
        }
    }

    // MARK: - Loading -
    @Test func testLoadErrorNotAnArray() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": {}
                   }
                   """.data(using:.utf8)!

        #expect(throws: RawDesignReaderError.typeMismatch("array", ["snapshots"])) {
            try reader.read(data: data)
        }
    }
    
    // TODO: Test malformed children (or all known raw object values in fact)
    @Test func loadEmpty() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": []
                   }
                   """.data(using:.utf8)!
        let design = try reader.read(data: data)
        #expect(design.snapshots.isEmpty)
    }
    @Test func loadEmptyWithMetamodelVersion() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "metamodel": "StockFlow",
                   "metamodel_version": "0.1"
                   }
                   """.data(using:.utf8)!
        let design = try reader.read(data: data)
        #expect(design.snapshots.isEmpty)
        #expect(design.metamodelName == "StockFlow")
        #expect(design.metamodelVersion == SemanticVersion(0, 1, 0))
    }

    @Test func snapshotNotAnObject() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": ["thing"]
                   }
                   """.data(using:.utf8)!

        #expect(throws: RawDesignReaderError.typeMismatch("dictionary", ["snapshots", "Index 0"])) {
            try reader.read(data: data)
        }
    }
    @Test func readFrames() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": [
                        {
                            "type": "Some",
                        }
                   ],
                   "frames": [
                        {
                            "id": 1000,
                            "snapshots": ["first"]
                        }
                   ]
                   }
                   """.data(using:.utf8)!
        let design = try reader.read(data: data)
        
        #expect(design.snapshots.count == 1)
        #expect(design.frames.count == 1)
        let frame = try #require(design.frames.first)
        #expect(frame.id == .id(1000))
        #expect(frame.snapshots == [.string("first")])
    }
    @Test func readSnapshotBasic() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": [
                        {
                            "type": "Some",
                            "id": "first",
                            "snapshot_id": 10,
                            "structure": "node",
                            "parent": 20
                        },
                   ]
                   }
                   """.data(using:.utf8)!

        let design = try reader.read(data: data)

        #expect(design.snapshots.count == 1)
        
        let snapshot = try #require(design.snapshots.first)
        #expect(snapshot.typeName == "Some")
        #expect(snapshot.structure == RawStructure("node", references: []))
        #expect(snapshot.objectID == .string("first"))
        #expect(snapshot.snapshotID == .id(10))
        #expect(snapshot.parent == .id(20))
    }
    @Test func readSnapshotStructure() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": [
                        { "id": "i" },
                        { "id": "u", "structure": "unstructured"},
                        { "id": "n", "structure": "node"},
                        { "id": "e", "structure": "edge", "origin": 10, "target": 20 },
                        { "id": "ie", "origin": 30, "target": 40 }
                   ]
                   }
                   """.data(using:.utf8)!
        let design = try reader.read(data: data)

        #expect(design.snapshots.count == 5)

        #expect(design.snapshots[0].objectID == .string("i"))
        #expect(design.snapshots[0].structure == RawStructure(nil, references: []))

        #expect(design.snapshots[1].objectID == .string("u"))
        #expect(design.snapshots[1].structure == RawStructure("unstructured", references: []))

        #expect(design.snapshots[2].objectID == .string("n"))
        #expect(design.snapshots[2].structure == RawStructure("node", references: []))

        #expect(design.snapshots[3].objectID == .string("e"))
        #expect(design.snapshots[3].structure == RawStructure("edge", references: [.id(10), .id(20)]))

        #expect(design.snapshots[4].objectID == .string("ie"))
        #expect(design.snapshots[4].structure == RawStructure("edge", references: [.id(30), .id(40)]))

    }

    @Test func readSnapshotAttributes() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": [
                        {
                            "attributes": {
                                "value": {"type": "int", "value": 10},
                                "position": {"type": "point", "value": [0.1, 0.2]},
                                "midpoints": {"type": "point_array", "items": [[1.1, 1.2], [2.1, 2.2]]}
                            }
                        },
                   ]
                   }
                   """.data(using:.utf8)!
        let design = try reader.read(data: data)

        #expect(design.snapshots.count == 1)
        
        let snapshot = try #require(design.snapshots.first)
        #expect(snapshot.attributes["value"] == Variant(10))
        #expect(snapshot.attributes["position"] == Variant(Point(0.1, 0.2)))
        #expect(snapshot.attributes["midpoints"] == Variant([Point(1.1, 1.2), Point(2.1, 2.2)]))
    }
    @Test func readHistory() throws {
        let data = """
                   {
                   "format_version": "0.1",
                   "snapshots": [ ],
                   "frames": [ ],
                   "user_references": [
                        {"name": "config", "type": "frame", "id": 10}
                   ],
                   "system_references": [
                        {"name": "current_frame", "type": "frame", "id": 20}
                   ],
                   "user_lists": [
                        {"name": "things", "item_type": "frame", "ids": [30, 40]}
                   ],
                   "system_lists": [
                        {"name": "undo", "item_type": "frame", "ids": [50, 60]},
                        {"name": "redo", "item_type": "frame", "ids": [70, 80]}
                   ]
                   }
                   """.data(using:.utf8)!
        let design = try reader.read(data: data)
        
        #expect(design.userReferences == [RawNamedReference("config", type: "frame", id: .id(10))])
        #expect(design.systemReferences == [RawNamedReference("current_frame", type: "frame", id: .id(20))])
    }
}

