//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/09/2023.
//

import Foundation
import XCTest
@testable import PoieticCore

final class FrameReaderTests: XCTestCase {
    
    var design: Design!
    var frame: MutableFrame!
    
    override func setUp() {
        design = Design(metamodel: TestMetamodel)
        frame = design.deriveFrame()
    }
   
    func defaultReader() throws -> ForeignFrameReader {
        let data = """
                   {
                   "frame_format_version": "0",
                   }
                   """.data(using:.utf8)!

        return try ForeignFrameReader(data: data, design: design)
    }
    
    func testNotADict() throws {
        let data = "[]".data(using:.utf8)!
        
        XCTAssertThrowsError(try ForeignFrameReader(data: data, design: design)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.JSONError(.typeMismatch(.object, nil)))

        }
    }
    func testMissingFormatVersion() throws {
        let data = "{}".data(using:.utf8)!
        
        XCTAssertThrowsError(try ForeignFrameReader(data: data, design: design)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.missingFrameFormatVersion)

        }
    }
    func testInvalidFormatVersion() throws {
        let data = """
                   {
                   "frame_format_version": 10
                   }
                   """.data(using:.utf8)!

        XCTAssertThrowsError(try ForeignFrameReader(data: data, design: design)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.JSONError(.typeMismatch(.string, "frame_format_version")))
        }
    }
    func testCollectionsNotAnArray() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "collections": "not_an_array"
                   }
                   """.data(using:.utf8)!

        XCTAssertThrowsError(try ForeignFrameReader(data: data, design: design)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.JSONError(.typeMismatch(.array, "collections")))
        }
    }
    func testCollectionItemNotAString() throws {
        let data = """
                   {
                   "frame_format_version": "1",
                   "collections": [10]
                   }
                   """.data(using:.utf8)!

        XCTAssertThrowsError(try ForeignFrameReader(data: data, design: design)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.JSONError(.typeMismatch(.string, nil)))
        }
    }
    
    func testEmptyInfoDefaultName() throws {
        let data = """
                   {
                   "frame_format_version": "0",
                   }
                   """.data(using:.utf8)!

        let reader = try ForeignFrameReader(data: data, design: design)
        XCTAssertEqual(reader.info.frameFormatVersion, "0")
        XCTAssertEqual(reader.info.collectionNames, ["objects"])
    }
    
    // MARK: - Loading -
    func testLoadErrorNotAnArray() throws {
        let data = """
                   {
                   }
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.JSONError(.typeMismatch(.array, nil)))
        }
    }
    // TODO: Test malformed children (or all known foreign object values in fact)
    func testLoadEmpty() throws {
        let data = """
                   [
                   ]
                   """.data(using:.utf8)!
        try defaultReader().read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 0)
        XCTAssertEqual(frame.removedObjects.count, 0)
    }
    
    func testLoadNoTypeError() throws {
        let data = """
                   [
                    {}
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.foreignObjectError(.missingObjectType, 0))
        }
    }

    func testLoadSingleUnknownObjectTypeError() throws {
        let data = """
                   [
                    {
                        "type": "Invalid"
                    }
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.unknownObjectType("Invalid", 0))
        }
    }
    func testLoadSingleNoID() throws {
        let data = """
                   [
                    { "type": "Unstructured" }
                   ]
                   """.data(using:.utf8)!
        try defaultReader().read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertIdentical(snapshot.type, Metamodel.Unstructured)
    }
    func testLoadSingleWithName() throws {
        let data = """
                   [
                    { "type": "Unstructured", "name": "test" }
                   ]
                   """.data(using:.utf8)!
        try defaultReader().read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertEqual(snapshot.name, "test")
    }

    func testLoadWithDefaultValue() throws {
        let data = """
                   [
                    { "type": "Stock", "name": "test" }
                   ]
                   """.data(using:.utf8)!
        try defaultReader().read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertNotNil(snapshot["value"])
        XCTAssertEqual(snapshot["value"], Variant(0))

    }

    func testLoadEdgeNoOriginTargetError() throws {
        let data_no_origin = """
                   [ { "type": "Parameter" } ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data_no_origin, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.foreignObjectError(.propertyNotFound("from"), 0))
        }

        let data_no_target = """
                   [ { "type": "Parameter", "from": "doesnotmatter" } ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data_no_target, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.foreignObjectError(.propertyNotFound("to"), 0))
        }
    }
    func testLoadEdgeInvalidOriginTargetIDs() throws {
        let data_no_origin = """
                   [
                    { "type": "Parameter", "from": "unknown", "to": "doesnotmatter" },
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data_no_origin, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.invalidReference("unknown", "origin", 0))
        }

        let data_no_target = """
                   [
                    { "type": "Parameter", "from": "x", "to": "unknown" },
                    {"type": "Stock", "name": "x"},
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data_no_target, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.invalidReference("unknown", "target", 0))
        }
    }
    func testShouldNotHaveOriginOrTarget() throws {
        let data_extra_origin = """
                   [
                    { "type": "Unstructured", "from": "invalid"}
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data_extra_origin, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.foreignObjectError(.extraPropertyFound("from"), 0))
        }

        let data_extra_target = """
                   [
                    { "type": "Stock", "to": "invalid"}
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data_extra_target, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.foreignObjectError(.extraPropertyFound("to"), 0))
        }
    }

    func testConnectEdge() throws {
        let data = """
                   [
                    { "type": "Parameter", "name": "param", "from":"src", "to":"drain" },
                    { "type": "Stock", "name": "src" },
                    { "type": "Stock", "name": "drain" }
                   ]
                   """.data(using:.utf8)!
        try defaultReader().read(data, into: frame)
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
                   [
                    { "type": "Unstructured", "name": "parent", "children": ["a", "b"] },
                    { "type": "Unstructured", "name": "a" },
                    { "type": "Unstructured", "name": "b" },
                    { "type": "Unstructured", "name": "c" }
                   ]
                   """.data(using:.utf8)!
        try defaultReader().read(data, into: frame)
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
                   [
                    { "type": "Unstructured", "children": ["unknown"] },
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try defaultReader().read(data, into: frame)){
            guard let error = $0 as? ForeignFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           ForeignFrameError.invalidReference("unknown", "child", 0))
        }
    }
}

