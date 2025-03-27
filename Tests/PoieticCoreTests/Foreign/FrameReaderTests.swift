//
//  JSONFrameReaderTests.swift
//
//
//  Created by Stefan Urbanek on 08/09/2023.
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
    let loader: ForeignFrameLoader
    let reader: JSONFrameReader
    
    init() throws {
        design = Design(metamodel: TestMetamodel)
        frame = design.createFrame()
        reader = JSONFrameReader()
        loader = ForeignFrameLoader()
    }
   
    @Test func notADict() throws {
        let data = "[]".data(using:.utf8)!
        
        #expect(throws: ForeignFrameError.typeMismatch("dictionary", [])) {
            try reader.read(data: data)
        }
    }

    @Test func testInvalidFormatVersion() throws {
        let data = """
                   {
                   "format_version": 10
                   }
                   """.data(using:.utf8)!

        #expect(throws: ForeignFrameError.typeMismatch("String", ["format_version"])) {
            try reader.read(data: data)
        }
    }

    @Test func testCollectionsNotAnArray() throws {
        let data = """
                   {
                   "collections": "not_an_array"
                   }
                   """.data(using:.utf8)!

        #expect(throws: ForeignFrameError.typeMismatch("array", ["collections"])) {
            try reader.read(data: data)
        }
    }

    @Test func testCollectionItemNotAString() throws {
        let data = """
                   {
                   "collections": [10]
                   }
                   """.data(using:.utf8)!

        #expect(throws: ForeignFrameError.typeMismatch("String", ["collections", "Index 0"])) {
            try reader.read(data: data)
        }
    }
    
    // MARK: - Loading -
    @Test func testLoadErrorNotAnArray() throws {
        let data = """
                   {
                   "frame_format_version": "0",
                   "objects": {}
                   }
                   """.data(using:.utf8)!

        #expect(throws: ForeignFrameError.typeMismatch("array", ["objects"])) {
            try reader.read(data: data)
        }
    }
    
    // TODO: Test malformed children (or all known foreign object values in fact)
    @Test func loadEmpty() throws {
        let data = """
                   {
                   "objects": []
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)
        #expect(frame.snapshots.count == 0)
        #expect(frame.removedObjects.count == 0)
    }
    
    @Test func loadNoTypeError() throws {
        let data = """
                   {
                   "objects": [{}]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        #expect(throws: FrameLoaderError.foreignObjectError(.propertyNotFound("type"), 0, nil)) {
            try loader.load(fframe, into: frame)
        }
    }

    @Test func loadSingleUnknownObjectTypeError() throws {
        let data = """
                   {
                   "objects": [{"type": "Invalid"}]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        #expect(throws: FrameLoaderError.unknownObjectType("Invalid", 0, nil)) {
            try loader.load(fframe, into: frame)
        }
    }
    @Test func loadSingleNoID() throws {
        let data = """
                   {
                   "objects": [
                        {"type": "Unstructured"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)

        #expect(frame.snapshots.count == 1)

        let snapshot = try #require(frame.snapshots.first)
        #expect(snapshot.type === TestMetamodel["Unstructured"])
    }
    @Test func loadSingleWithName() throws {
        let data = """
                   {
                   "objects": [
                        {"type": "Unstructured", "id":"test"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)

        #expect(frame.snapshots.count == 1)

        let snapshot = try #require(frame.snapshots.first)
        #expect(snapshot.name == "test")
    }

    @Test func loadWithDefaultValue() throws {
        let data = """
                   {
                   "objects": [
                    { "type": "Stock", "id": "test" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)

        #expect(frame.snapshots.count == 1)

        let snapshot = try #require(frame.snapshots.first)
        #expect(snapshot["value"] == Variant(0))

    }

    @Test func testLoadWithAttributes() throws {
        let data = """
                   {
                   "objects": [
                        {
                            "type": "Stock",
                            "attributes": {"name": "Felix"}
                        }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)

        #expect(frame.snapshots.count == 1)

        let snapshot = try #require(frame.snapshots.first)
        #expect(snapshot["name"] == Variant("Felix"))
    }

    @Test func structureTypeMismatch() throws {
        let data_no_origin = """
                   {
                   "objects": [
                    { "type": "Parameter" }
                   ]
                   }
                   """.data(using:.utf8)!
        
        let fframe = try #require(try reader.read(data: data_no_origin))
        
        #expect(throws: FrameLoaderError.structureMismatch(.edge, 0, nil)) {
            try loader.load(fframe, into: frame)
        }
    }
    @Test func missingEdgeTo() throws {
        let data_no_target = """
                   {
                   "objects": [
                    { "type": "Parameter", "from": "doesnotmatter" }
                   ]
                   }
                   """.data(using:.utf8)!

        #expect(throws: ForeignFrameError.foreignObjectError(.invalidStructureType, 0)) {
            try reader.read(data: data_no_target)
        }
    }

    @Test func testLoadEdgeInvalidOriginTargetIDs() throws {
        let data_no_origin = """
                   {
                   "objects": [
                    { "type": "Parameter", "from": "unknown", "to": "doesnotmatter" },
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data_no_origin))

        #expect(throws: FrameLoaderError.invalidReference("origin", .string("unknown"), 0, nil)) {
            try loader.load(fframe, into: frame)
        }

        let data_no_target = """
                   {
                   "objects": [
                        { "type": "Parameter", "from": "x", "to": "unknown" },
                        { "type": "Stock", "id": "x"},
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe2 = try #require(try reader.read(data: data_no_target))

        #expect(throws: FrameLoaderError.invalidReference("target", .string("unknown"), 0, nil)) {
            try loader.load(fframe2, into: frame)
        }
    }
    
    @Test func shouldNotHaveOriginOrTarget() throws {
        let data_extra_origin = """
                   {
                   "objects": [
                        { "type": "Unstructured", "from": "invalid", "to": "invalid"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data_extra_origin))
        #expect(throws: FrameLoaderError.structureMismatch(.unstructured, 0, nil)) {
            try loader.load(fframe, into: frame)
        }

        let data_extra_target = """
                   {
                   "objects": [
                        { "type": "Stock", "from":"invalid", "to": "invalid"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe2 = try #require(try reader.read(data: data_extra_target))
        #expect(throws: FrameLoaderError.structureMismatch(.node, 0, nil)) {
            try loader.load(fframe2, into: frame)
        }
    }

    @Test func connectEdge() throws {
        let data = """
                   {
                   "objects": [
                        { "type": "Parameter", "id": "param", "from":"src", "to":"drain" },
                        { "type": "Stock", "id": "src" },
                        { "type": "Stock", "id": "drain" }
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)

        #expect(frame.snapshots.count == 3)
        
        let param = try #require(frame.object(named: "param"))
        let src = try #require(frame.object(named: "src"))
        let drain = try #require(frame.object(named: "drain"))
        
        #expect(param.structure == Structure.edge(src.id, drain.id))
    }

    @Test func testConnectChildren() throws {
        let data = """
                   {
                   "objects": [
                        { "type": "Unstructured", "id": "parent"},
                        { "type": "Unstructured", "id": "a", "parent": "parent" },
                        { "type": "Unstructured", "id": "b", "parent": "parent"  },
                        { "type": "Unstructured", "id": "c" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        try loader.load(fframe, into: frame)

        #expect(frame.snapshots.count == 4)
        
        let parent = frame.object(named: "parent")!
        let a = frame.object(named: "a")!
        let b = frame.object(named: "b")!
        let c = frame.object(named: "c")!
        
        #expect(parent.children.contains(a.id))
        #expect(parent.parent == nil)
        #expect(a.parent == parent.id)
        #expect(b.parent == parent.id)
        #expect(c.parent == nil)
    }

//    @Test func testUnknownChildReference() throws {
//        let data = """
//                   {
//                   "objects": [
//                        { "type": "Unstructured", "children": ["unknown"] },
//                   ]
//                   }
//                   """.data(using:.utf8)!
//        let fframe = try #require(try reader.read(data: data))
//        #expect(throws: FrameLoaderError.invalidReference("child", .string("unknown"), 0, nil)) {
//            try loader.load(fframe, into: frame)
//        }
//    }
}

