//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 10/07/2023.
//

import XCTest
@testable import PoieticCore

final class VariantTests: XCTestCase {
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

// FIXME: Review this
final class OldForeignValueJSONTests: XCTestCase {
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
}


final class VariantJSONCodableTests: XCTestCase {
    var decoder: JSONDecoder!
    
    override func setUp() {
        decoder = JSONDecoder()
    }
    
    func testDecodeTypedInt() throws {
        let data = "[\"i\", 1234]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(1234))
        XCTAssertEqual(value.valueType, .atom(.int))
    }
    
    func testDecodeTypedDouble() throws {
        let data = "[\"d\", 1234]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(1234.0))
        XCTAssertEqual(value.valueType, .atom(.double))
    }
    
    func testDecodeTypedBool() throws {
        let data = "[\"b\", true]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(true))
        XCTAssertEqual(value.valueType, .atom(.bool))
    }
    
    func testDecodeTypedString() throws {
        let data = "[\"s\", \"hello\"]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant("hello"))
        XCTAssertEqual(value.valueType, .atom(.string))
    }
    
    func testDecodeTypedPoint() throws {
        let data = "[\"p\", [10, 20]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(Point(x: 10, y: 20)))
        XCTAssertEqual(value.valueType, .atom(.point))
    }
    
    func testDecodeTypedIntArray() throws {
        let data = "[\"ai\", [1234, 5678]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([1234, 5678]))
        XCTAssertEqual(value.valueType, .array(.int))
    }
    
    func testDecodeTypedDoubleArray() throws {
        let data = "[\"ad\", [1234, 5678]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([1234.0, 5678.0]))
        XCTAssertEqual(value.valueType, .array(.double))
    }
    
    func testDecodeTypedBoolArray() throws {
        let data = "[\"ab\", [true, false]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([true, false]))
        XCTAssertEqual(value.valueType, .array(.bool))
    }
    
    func testDecodeTypedStringArray() throws {
        let data = "[\"as\", [\"hello\", \"there\"]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(["hello", "there"]))
        XCTAssertEqual(value.valueType, .array(.string))
    }
    
    func testDecodeTypedPointArray() throws {
        let data = "[\"ap\", [[10, 20], [30, 40]]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([Point(x: 10, y: 20), Point(x: 30, y: 40)]))
        XCTAssertEqual(value.valueType, .array(.point))
    }
    
    // MARK: Coalesced
    
    func testDecodeCoalescedInt() throws {
        let data = "1234".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(1234))
        XCTAssertEqual(value.valueType, .atom(.int))
    }
    
    func testDecodeCoalescedDouble() throws {
        let data = "1234.5".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(1234.5))
        XCTAssertEqual(value.valueType, .atom(.double))
    }
    func testDecodeCoalescedString() throws {
        let data = "\"hello\"".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant("hello"))
        XCTAssertEqual(value.valueType, .atom(.string))
    }
    func testDecodeCoalescedBool() throws {
        let data = "true".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(true))
        XCTAssertEqual(value.valueType, .atom(.bool))
    }
    
    func testDecodeCoalescedIntArray() throws {
        let data = "[12, 34]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([12, 34]))
        XCTAssertEqual(value.valueType, .array(.int))
    }
    
    func testDecodeCoalescedDoubleArray() throws {
        let data = "[12.3, 4.5]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([12.3, 4.5]))
        XCTAssertEqual(value.valueType, .array(.double))
    }
    func testDecodeCoalescedStringArray() throws {
        let data = "[\"hello\", \"there\"]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant(["hello", "there"]))
        XCTAssertEqual(value.valueType, .array(.string))
    }
    func testDecodeCoalescedBoolArray() throws {
        let data = "[true, false, true]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([true, false, true]))
        XCTAssertEqual(value.valueType, .array(.bool))
    }
    func testDecodeCoalescedMixedDoubleArray() throws {
        let data = "[10, 20, 30.4]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([10, 20, 30.4]))
        XCTAssertEqual(value.valueType, .array(.double))
    }
    func testDecodeCoalescedPointArray() throws {
        let data = "[[10, 20], [30, 40]]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        XCTAssertEqual(value, Variant([Point(x:10, y:20), Point(x:30, y:40)]))
        XCTAssertEqual(value.valueType, .array(.point))
    }
    // TODO: Test invalid point value
    // TODO: Test invalid values
}
