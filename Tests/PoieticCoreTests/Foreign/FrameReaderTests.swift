//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/09/2023.
//

import Foundation
import Testing
@testable import PoieticCore

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
                   "frame_format_version": 10
                   }
                   """.data(using:.utf8)!

        #expect(throws: ForeignFrameError.typeMismatch("String", ["frame_format_version"])) {
            try reader.read(data: data)
        }
    }

    @Test func testCollectionsNotAnArray() throws {
        let data = """
                   {
                   "frame_format_version": "0",
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
                   "frame_format_version": "0",
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
                   "frame_format_version": "0",
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
                   "frame_format_version": "0",
                   "objects": [{}]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        #expect(throws: FrameLoaderError.foreignObjectError(.missingObjectType, nil)) {
            try loader.load(fframe, into: frame)
        }
    }

    @Test func loadSingleUnknownObjectTypeError() throws {
        let data = """
                   {
                   "frame_format_version": "0",
                   "objects": [{"type": "Invalid"}]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data))
        #expect(throws: FrameLoaderError.unknownObjectType("Invalid", nil)) {
            try loader.load(fframe, into: frame)
        }
    }
    @Test func loadSingleNoID() throws {
        let data = """
                   {
                   "frame_format_version": "0",
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
                   "frame_format_version": "0",
                   "objects": [
                        {"type": "Unstructured", "name":"test"}
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
                   "frame_format_version": "0",
                   "objects": [
                    { "type": "Stock", "name": "test" }
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
                   "frame_format_version": "0",
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

    @Test func testLoadEdgeNoOriginTargetError() throws {
        let data_no_origin = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                    { "type": "Parameter" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try #require(try reader.read(data: data_no_origin))

        #expect(throws: FrameLoaderError.foreignObjectError(.propertyNotFound("from"), nil)) {
            try loader.load(fframe, into: frame)
        }

        let data_no_target = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                    { "type": "Parameter", "from": "doesnotmatter" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe2 = try #require(try reader.read(data: data_no_target))

        #expect(throws: FrameLoaderError.foreignObjectError(.propertyNotFound("to"), nil)) {
            try loader.load(fframe2, into: frame)
        }
    }

    @Test func testLoadEdgeInvalidOriginTargetIDs() throws {
        let data_no_origin = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                    { "type": "Parameter", "from": "unknown", "to": "doesnotmatter" },
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data_no_origin))

        #expect(throws: FrameLoaderError.invalidReference("unknown", "origin", nil)) {
            try loader.load(fframe, into: frame)
        }

        let data_no_target = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                        { "type": "Parameter", "from": "x", "to": "unknown" },
                        { "type": "Stock", "name": "x"},
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe2 = try #require(try reader.read(data: data_no_target))

        #expect(throws: FrameLoaderError.invalidReference("unknown", "target", nil)) {
            try loader.load(fframe2, into: frame)
        }
    }
    
    @Test func shouldNotHaveOriginOrTarget() throws {
        let data_extra_origin = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                        { "type": "Unstructured", "from": "invalid"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data_extra_origin))
        #expect(throws: FrameLoaderError.foreignObjectError(.extraPropertyFound("from"), nil)) {
            try loader.load(fframe, into: frame)
        }

        let data_extra_target = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                        { "type": "Stock", "to": "invalid"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe2 = try #require(try reader.read(data: data_extra_target))
        #expect(throws: FrameLoaderError.foreignObjectError(.extraPropertyFound("to"), nil)) {
            try loader.load(fframe2, into: frame)
        }
    }

    @Test func connectEdge() throws {
        let data = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                        { "type": "Parameter", "name": "param", "from":"src", "to":"drain" },
                        { "type": "Stock", "name": "src" },
                        { "type": "Stock", "name": "drain" }
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

    func testConnectChildren() throws {
        let data = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                        { "type": "Unstructured", "name": "parent", "children": ["a", "b"] },
                        { "type": "Unstructured", "name": "a" },
                        { "type": "Unstructured", "name": "b" },
                        { "type": "Unstructured", "name": "c" }
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
        
        #expect(parent.children == [a.id, b.id])
        #expect(parent.parent == nil)
        #expect(a.parent == parent.id)
        #expect(b.parent == parent.id)
        #expect(c.parent == nil)
    }

    func testUnknownChildReference() throws {
        let data = """
                   {
                   "frame_format_version": "0",
                   "objects": [
                        { "type": "Unstructured", "children": ["unknown"] },
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try #require(try reader.read(data: data))
        #expect(throws: FrameLoaderError.invalidReference("unknown", "child", nil)) {
            try loader.load(fframe, into: frame)
        }
    }
}

