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
    
    var memory: ObjectMemory!
    var frame: MutableFrame!
    var reader: ForeignFrameReader!
    
    override func setUp() {
        memory = ObjectMemory(metamodel: TestMetamodel)
        frame = memory.deriveFrame()
        
        let infoSrc = """
                      {
                        "frameFormatVersion": "0"
                      }
                      """.data(using:.utf8)!
        
        reader = try! ForeignFrameReader(data: infoSrc, memory: memory)
    }
    
    func testInvalidEmpty() throws {
        let infoSrc = "{}".data(using:.utf8)!
        
        XCTAssertThrowsError(try ForeignFrameReader(data: infoSrc, memory: memory)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.propertyNotFound("frameFormatVersion"))
        }
    }
    func testEmpty() throws {
        let infoSrc = """
                      {
                        "frameFormatVersion": "0"
                      }
                      """.data(using:.utf8)!
        
        let reader = try ForeignFrameReader(data: infoSrc, memory: memory)
        XCTAssertEqual(reader.info.frameFormatVersion, "0")
    }
    func testLoadErrorNotAnArray() throws {
        let data = """
                   {
                   }
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.typeMismatch([]))
        }
    }
    func testLoadEmpty() throws {
        let data = """
                   [
                   ]
                   """.data(using:.utf8)!
        try reader.read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 0)
        XCTAssertEqual(frame.removedObjects.count, 0)
    }
    
    func testLoadNoTypeError() throws {
        let data = """
                   [
                    {}
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.objectPropertyNotFound("type", 0))
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
        XCTAssertThrowsError(try reader.read(data, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.unknownObjectType("Invalid", 0))
        }
    }
    func testLoadSingleNoID() throws {
        let data = """
                   [
                    { "type": "Unstructured" }
                   ]
                   """.data(using:.utf8)!
        try reader.read(data, into: frame)
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
        try reader.read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertEqual(snapshot.name, "test")
    }
    
    func testLoadWithDefaultComponent() throws {
        let data = """
                   [
                    { "type": "Stock", "name": "test" }
                   ]
                   """.data(using:.utf8)!
        try reader.read(data, into: frame)
        XCTAssertEqual(frame.snapshots.count, 1)

        let snapshot = frame.snapshots.first!
        XCTAssertTrue(snapshot.components.has(IntegerComponent.self))
        XCTAssertEqual(snapshot.attribute(forKey: "value"), ForeignValue(0))

    }
    
    func testLoadEdgeNoOriginTargetError() throws {
        let data_no_origin = """
                   [ { "type": "Parameter" } ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data_no_origin, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.objectPropertyNotFound("from", 0))
        }

        let data_no_target = """
                   [ { "type": "Parameter", "from": "doesnotmatter" } ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data_no_target, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.objectPropertyNotFound("to", 0))
        }
    }
    func testLoadEdgeInvalidOriginTargetIDs() throws {
        let data_no_origin = """
                   [
                    { "type": "Parameter", "from": "unknown", "to": "doesnotmatter" },
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data_no_origin, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.invalidObjectReference("unknown", "origin", 0))
        }

        let data_no_target = """
                   [
                    { "type": "Parameter", "from": "x", "to": "unknown" },
                    {"type": "Stock", "name": "x"},
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data_no_target, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.invalidObjectReference("unknown", "target", 0))
        }
    }
    func testShouldNotHaveOriginOrTarget() throws {
        let data_extra_origin = """
                   [
                    { "type": "Unstructured", "from": "invalid"}
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data_extra_origin, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.invalidStructuralKeyPresent("from", .unstructured, 0))
        }

        let data_extra_target = """
                   [
                    { "type": "Stock", "to": "invalid"}
                   ]
                   """.data(using:.utf8)!
        XCTAssertThrowsError(try reader.read(data_extra_target, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.invalidStructuralKeyPresent("to", .node, 0))
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
        try reader.read(data, into: frame)
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
        try reader.read(data, into: frame)
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
        XCTAssertThrowsError(try reader.read(data, into: frame)){
            guard let error = $0 as? FrameReaderError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error,
                           FrameReaderError.invalidObjectReference("unknown", "child", 0))
        }
    }
}

