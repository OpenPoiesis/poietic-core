//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 10/07/2023.
//

import XCTest
@testable import PoieticCore

final class ForeignValueTests: XCTestCase {
    func testIntFromString() throws {
        XCTAssertEqual(try Variant("10").intValue(), 10)
        // TODO: Accept underscore in numeric values
//        XCTAssertEqual(try Variant("1_0_0").intValue(), 100)

        XCTAssertThrowsError(try Variant("10x").intValue())
        XCTAssertThrowsError(try Variant("").intValue())
    }
    func testDoubleFromString() throws {
        let value1 = try Variant("3.14e2").doubleValue()
        XCTAssertEqual(value1, 3.14e2)

        XCTAssertThrowsError(try Variant("10x").doubleValue())
        XCTAssertThrowsError(try Variant("").doubleValue())
    }
    func testBoolFromString() throws {
        let value1 = try Variant("true").boolValue()
        XCTAssertEqual(value1, true)

        let value2 = try Variant("false").boolValue()
        XCTAssertEqual(value2, false)
        
        XCTAssertThrowsError(try Variant("something").boolValue())
        XCTAssertThrowsError(try Variant("").boolValue())
    }
    func testPointFromString() throws {
        XCTAssertEqual(try Variant("1.2x3.4").pointValue(), Point(x:1.2, y:3.4))
        // TODO: Accept underscore in numeric values
//        XCTAssertEqual(try Variant("1_0_0").intValue(), 100)

        XCTAssertThrowsError(try Variant("10 x 20").pointValue())
        XCTAssertThrowsError(try Variant("10x").pointValue())
        XCTAssertThrowsError(try Variant("x10").pointValue())
        XCTAssertThrowsError(try Variant("x").pointValue())
        XCTAssertThrowsError(try Variant("").intValue())
    }
    func testStringToPoint() throws {
        XCTAssertEqual(try Variant(Point(x:1.0, y:2.0)).stringValue(), "1.0x2.0")
    }
    
    func testTwoItemArrayIsAPointConvertible() throws {
        XCTAssertEqual(try Variant([1, 2]).pointValue(), Point(1.0, 2.0))

    }

}

final class ForeignValueJSONTests: XCTestCase {
    func testJSONValueDecoding() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("10".utf8)),
                       .int(10))
        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("true".utf8)),
                       .bool(true))
        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("10.2".utf8)),
                       .double(10.2))
        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("\"text\"".utf8)),
                       .string("text"))
        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("null".utf8)),
                       .null)

        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("[10, true]".utf8)),
                       .array([.int(10), .bool(true)]))
        
        XCTAssertEqual(try decoder.decode(JSONValue.self,
                                          from: Data("{\"a\": 10, \"b\": true}".utf8)),
                       .object(["a": .int(10), "b": .bool(true)]))
    }
    func testJSONValueEncoding() throws {
        XCTAssertEqual(try JSONValue.int(10).asJSONString(), "10")
        XCTAssertEqual(try JSONValue.double(10.2).asJSONString(), "10.2")
        XCTAssertEqual(try JSONValue.bool(true).asJSONString(), "true")
        XCTAssertEqual(try JSONValue.string("text").asJSONString(), "\"text\"")
        XCTAssertEqual(try JSONValue.null.asJSONString(), "null")
        XCTAssertEqual(try JSONValue.array([.int(10), .bool(true)]).asJSONString(),
                       "[10,true]")
        XCTAssertEqual(try JSONValue.object(["a": .int(10)]).asJSONString(),
                       "{\"a\":10}")
    }

    func toJSON(_ string: String) -> JSONValue {
        return try! JSONValue(string: string)
    }
    
    func testVariantFromJSON() throws {
        // TODO: Int should be int
        XCTAssertEqual(try Variant.fromJSON(toJSON("0")).valueType, .int)
        XCTAssertEqual(try Variant.fromJSON(toJSON("1")).valueType, .int)
        XCTAssertEqual(try Variant.fromJSON(toJSON("10")).valueType, .int)
        XCTAssertEqual(try Variant.fromJSON(toJSON("10.0")).valueType, .int)
        XCTAssertEqual(try Variant.fromJSON(toJSON("12.3")).valueType, .double)
        XCTAssertEqual(try Variant.fromJSON(toJSON("true")).valueType, .bool)
        XCTAssertEqual(try Variant.fromJSON(toJSON("\"hello\"")).valueType, .string)
        XCTAssertEqual(try Variant.fromJSON(toJSON("[10, 20]")).valueType, .ints)
        XCTAssertEqual(try Variant.fromJSON(toJSON("[[10, 20]]")).valueType, .points)
    }
    
    func testAtomToJSON() throws {
        XCTAssertEqual(try VariantAtom(10).asJSON().asJSONString(), "10")
        XCTAssertEqual(try VariantAtom(10.1).asJSON().asJSONString(), "10.1")
        XCTAssertEqual(try VariantAtom(true).asJSON().asJSONString(), "true")
        XCTAssertEqual(try VariantAtom("hello").asJSON().asJSONString(), "\"hello\"")
        XCTAssertEqual(try VariantAtom(Point(10, 20)).asJSON().asJSONString(), "[10,20]")
    }
//    
//    
//    func testValueFromJSON() throws {
//        // TODO: Int should be int
//        XCTAssertEqual(try Variant.fromJSON("10").valueType, .double)
//        XCTAssertEqual(try ForeignValue.fromJSON("10.0").valueType, .double)
//        XCTAssertEqual(try ForeignValue.fromJSON("true").valueType, .bool)
//        XCTAssertEqual(try ForeignValue.fromJSON("\"hello\"").valueType, .string)
////        XCTAssertEqual(try ForeignValue.fromJSON("[10, 20]").valueType, .point)
//
//        XCTAssertEqual(try ForeignValue.fromJSON("[10, 20]").arrayItemType, .double)
//        XCTAssertEqual(try ForeignValue.fromJSON("[\"a\", \"b\"]").arrayItemType, .string)
//        XCTAssertEqual(try ForeignValue.fromJSON("[[10, 20], [30, 40]]").arrayItemType, .point)
//
//        XCTAssertThrowsError(try ForeignValue.fromJSON("[\"a\", 10]"))
//    }
}
