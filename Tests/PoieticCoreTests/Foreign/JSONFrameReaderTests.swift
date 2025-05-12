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
        reader = JSONDesignReader()
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
        let snapshot = try #require(design.snapshots.first)
        #expect(frame.id == .int(1000))
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
        #expect(snapshot.id == .string("first"))
        #expect(snapshot.snapshotID == .int(10))
        #expect(snapshot.parent == .int(20))
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
        
        #expect(design.userReferences == [RawNamedReference("config", type: "frame", id: .int(10))])
        #expect(design.systemReferences == [RawNamedReference("current_frame", type: "frame", id: .int(20))])
    }
}

