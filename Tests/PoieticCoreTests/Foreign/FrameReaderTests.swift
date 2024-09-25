//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/09/2023.
//

import Foundation
import XCTest
@testable import PoieticCore

final class JSONFrameReaderTests: XCTestCase {
    
    var design: Design!
    var frame: MutableFrame!
    var loader: ForeignFrameLoader!
    var reader: JSONFrameReader!
    
    override func setUp() {
        design = Design(metamodel: TestMetamodel)
        frame = design.deriveFrame()
        reader = JSONFrameReader()
        loader = ForeignFrameLoader()
    }
   
    func testNotADict() throws {
        let data = "[]".data(using:.utf8)!
        
        XCTAssertThrowsError(try reader.read(data: data)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.typeMismatch("dictionary", []))

        }
    }
    func testMissingFormatVersion() throws {
        let data = "{}".data(using:.utf8)!
        
        XCTAssertThrowsError(try reader.read(data: data)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.propertyNotFound("frame_format_version", []))

        }
    }
    func testInvalidFormatVersion() throws {
        let data = """
                   {
                   "frame_format_version": 10
                   }
                   """.data(using:.utf8)!

        XCTAssertThrowsError(try reader.read(data: data)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.typeMismatch("String", ["frame_format_version"]))
        }
    }
    func testCollectionsNotAnArray() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "collections": "not_an_array"
                   }
                   """.data(using:.utf8)!

        XCTAssertThrowsError(try reader.read(data: data)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.typeMismatch("array", ["collections"]))
        }
    }
    func testCollectionItemNotAString() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "collections": [10]
                   }
                   """.data(using:.utf8)!

        XCTAssertThrowsError(try reader.read(data: data)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.typeMismatch("String", ["collections", "Index 0"]))
        }
    }
    
    // MARK: - Loading -
    func testLoadErrorNotAnArray() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": {}
                   }
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data: data)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.typeMismatch("array", ["objects"]))
        }
    }
    
    // TODO: Test malformed children (or all known foreign object values in fact)
    func testLoadEmpty() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": []
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)
        XCTAssertEqual(frame.snapshots.count, 0)
        XCTAssertEqual(frame.removedObjects.count, 0)
    }
    
    func testLoadNoTypeError() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [{}]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)
        XCTAssertThrowsError(try loader.load(fframe, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.foreignObjectError(.missingObjectType, nil))
        }
    }

    func testLoadSingleUnknownObjectTypeError() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [{"type": "Invalid"}]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)
        XCTAssertThrowsError(try loader.load(fframe, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.unknownObjectType("Invalid", nil))
        }
    }
    func testLoadSingleNoID() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        {"type": "Unstructured"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)

        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertIdentical(snapshot.type, TestMetamodel["Unstructured"])
    }
    func testLoadSingleWithName() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        {"type": "Unstructured", "name":"test"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)

        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertEqual(snapshot.name, "test")
    }

    func testLoadWithDefaultValue() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                    { "type": "Stock", "name": "test" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)

        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertNotNil(snapshot["value"])
        XCTAssertEqual(snapshot["value"], Variant(0))

    }
    func testLoadWithAttributes() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        {
                            "type": "Stock",
                            "attributes": {"name": "Felix"}
                        }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)

        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertNotNil(snapshot["name"])
        XCTAssertEqual(snapshot["name"], Variant("Felix"))

    }

    func testLoadEdgeNoOriginTargetError() throws {
        let data_no_origin = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                    { "type": "Parameter" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try! reader.read(data: data_no_origin)

        XCTAssertThrowsError(try loader.load(fframe, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.foreignObjectError(.propertyNotFound("from"), nil))
        }

        let data_no_target = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                    { "type": "Parameter", "from": "doesnotmatter" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe2 = try! reader.read(data: data_no_target)

        XCTAssertThrowsError(try loader.load(fframe2, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.foreignObjectError(.propertyNotFound("to"), nil))
        }
    }

    func testLoadEdgeInvalidOriginTargetIDs() throws {
        let data_no_origin = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                    { "type": "Parameter", "from": "unknown", "to": "doesnotmatter" },
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data_no_origin)

        XCTAssertThrowsError(try loader.load(fframe, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.invalidReference("unknown", "origin", nil))
        }

        let data_no_target = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        { "type": "Parameter", "from": "x", "to": "unknown" },
                        { "type": "Stock", "name": "x"},
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe2 = try! reader.read(data: data_no_target)

        XCTAssertThrowsError(try loader.load(fframe2, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.invalidReference("unknown", "target", nil))
        }
    }
    
    func testShouldNotHaveOriginOrTarget() throws {
        let data_extra_origin = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        { "type": "Unstructured", "from": "invalid"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data_extra_origin)

        XCTAssertThrowsError(try loader.load(fframe, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.foreignObjectError(.extraPropertyFound("from"), nil))
        }

        let data_extra_target = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        { "type": "Stock", "to": "invalid"}
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe2 = try! reader.read(data: data_extra_target)

        XCTAssertThrowsError(try loader.load(fframe2, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.foreignObjectError(.extraPropertyFound("to"), nil))
        }
    }

    func testConnectEdge() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        { "type": "Parameter", "name": "param", "from":"src", "to":"drain" },
                        { "type": "Stock", "name": "src" },
                        { "type": "Stock", "name": "drain" }
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)

        XCTAssertEqual(frame.snapshots.count, 3)
        
        guard let param = frame.object(named: "param") else {
            XCTFail("Object 'param' was not instantiated")
            return
        }
        guard let src = frame.object(named: "src") else {
            XCTFail("Object 'src' was not instantiated")
            return
        }
        guard let drain = frame.object(named: "drain") else {
            XCTFail("Object 'drain' was not instantiated")
            return
        }
        
        XCTAssertEqual(param.structure, StructuralComponent.edge(src.id, drain.id))

    }

    func testConnectChildren() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        { "type": "Unstructured", "name": "parent", "children": ["a", "b"] },
                        { "type": "Unstructured", "name": "a" },
                        { "type": "Unstructured", "name": "b" },
                        { "type": "Unstructured", "name": "c" }
                   ]
                   }
                   """.data(using:.utf8)!

        let fframe = try! reader.read(data: data)
        try loader.load(fframe, into: frame)

        XCTAssertEqual(frame.snapshots.count, 4)
        
        let parent = frame.object(named: "parent")!
        let a = frame.object(named: "a")!
        let b = frame.object(named: "b")!
        let c = frame.object(named: "c")!
        
        XCTAssertEqual(parent.children, [a.id, b.id])
        XCTAssertEqual(parent.parent, nil)
        XCTAssertEqual(a.parent, parent.id)
        XCTAssertEqual(b.parent, parent.id)
        XCTAssertEqual(c.parent, nil)
    }

    func testUnknownChildReference() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "objects": [
                        { "type": "Unstructured", "children": ["unknown"] },
                   ]
                   }
                   """.data(using:.utf8)!
        let fframe = try! reader.read(data: data)

        XCTAssertThrowsError(try loader.load(fframe, into: frame)){
            guard let error = $0 as? FrameLoaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameLoaderError.invalidReference("unknown", "child", nil))
        }
    }
}

