//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 10/07/2023.
//

import Testing
@testable import PoieticCore

@Suite struct VariantTests {
    @Test func stringToInt() throws {
        #expect(try Variant("10").intValue() == 10)

        #expect(throws: ValueError.conversionFailed(.string, .int)) {
            try Variant("10.5").intValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .int)) {
            try Variant("10x").intValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .int)) {
            try Variant("").intValue()
        }
    }

    @Test func stringToDouble() throws {
        #expect(try Variant("3.14e2").doubleValue() == 3.14e2)
        #expect(try Variant("10").doubleValue() == 10.0)

        #expect(throws: ValueError.conversionFailed(.string, .double)) {
            try Variant("10x").doubleValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .double)) {
            try Variant("").doubleValue()
        }
    }

    @Test func stringToBool() throws {
        let value1 = try Variant("true").boolValue()
        #expect(value1 == true)

        let value2 = try Variant("false").boolValue()
        #expect(value2 == false)
        
        #expect(throws: ValueError.conversionFailed(.string, .bool)) {
            try Variant("something").boolValue()
        }

        #expect(throws: ValueError.conversionFailed(.string, .bool)) {
            try Variant("").boolValue()
        }
    }

    @Test func stringToPoint() throws {
        #expect(try Variant("[10,20]").pointValue() == Point(x:10, y:20))
        #expect(try Variant("[1.2,3.4]").pointValue() == Point(x:1.2, y:3.4))

        // Old point string representation, now invalid
        #expect(throws: ValueError.conversionFailed(.string, .point)) {
            try Variant("10 x 20").pointValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .point)) {
            try Variant("10x").pointValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .point)) {
            try Variant("x10").pointValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .point)) {
            try Variant("x").pointValue()
        }
        #expect(throws: ValueError.conversionFailed(.string, .point)) {
            try Variant("").pointValue()
        }
    }
    
    @Test func pointFromSomethingNonconvertible() throws {
        #expect(throws: ValueError.notConvertible(.int, .point)) {
            try Variant(10).pointValue()
        }
        #expect(throws: ValueError.notConvertible(.double, .point)) {
            try Variant(3.14).pointValue()
        }
        #expect(throws: ValueError.notConvertible(.bool, .point)) {
            try Variant(true).pointValue()
        }
    }

    @Test func pointToString() throws {
        #expect(try Variant(Point(x:1.0, y:2.0)).stringValue() == "[1.0,2.0]")
    }
    
    @Test func testTwoItemArrayIsAPointConvertible() throws {
        #expect(try Variant([1, 2]).pointValue() == Point(1.0, 2.0))

    }
}

/*
final class VariantJSONCodableTests: XCTestCase {
    var decoder: JSONDecoder!
    
    override func setUp() {
        decoder = JSONDecoder()
    }
    
    func testDecodeTypedInt() throws {
        let data = "[\"i\", 1234]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(1234))
        #expect(value.valueType, .atom(.int))
    }
    
    func testDecodeTypedDouble() throws {
        let data = "[\"d\", 1234]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(1234.0))
        #expect(value.valueType, .atom(.double))
    }
    
    func testDecodeTypedBool() throws {
        let data = "[\"b\", true]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(true))
        #expect(value.valueType, .atom(.bool))
    }
    
    func testDecodeTypedString() throws {
        let data = "[\"s\", \"hello\"]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant("hello"))
        #expect(value.valueType, .atom(.string))
    }
    
    func testDecodeTypedPoint() throws {
        let data = "[\"p\", [10, 20]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(Point(x: 10, y: 20)))
        #expect(value.valueType, .atom(.point))
    }
    
    func testDecodeTypedIntArray() throws {
        let data = "[\"ai\", [1234, 5678]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([1234, 5678]))
        #expect(value.valueType, .array(.int))
    }
    
    func testDecodeTypedDoubleArray() throws {
        let data = "[\"ad\", [1234, 5678]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([1234.0, 5678.0]))
        #expect(value.valueType, .array(.double))
    }
    
    func testDecodeTypedBoolArray() throws {
        let data = "[\"ab\", [true, false]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([true, false]))
        #expect(value.valueType, .array(.bool))
    }
    
    func testDecodeTypedStringArray() throws {
        let data = "[\"as\", [\"hello\", \"there\"]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(["hello", "there"]))
        #expect(value.valueType, .array(.string))
    }
    
    func testDecodeTypedPointArray() throws {
        let data = "[\"ap\", [[10, 20], [30, 40]]]".data(using:.utf8)!
        
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([Point(x: 10, y: 20), Point(x: 30, y: 40)]))
        #expect(value.valueType, .array(.point))
    }
    
    // MARK: Coalesced
    
    func testDecodeCoalescedInt() throws {
        let data = "1234".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(1234))
        #expect(value.valueType, .atom(.int))
    }
    
    func testDecodeCoalescedDouble() throws {
        let data = "1234.5".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(1234.5))
        #expect(value.valueType, .atom(.double))
    }
    func testDecodeCoalescedString() throws {
        let data = "\"hello\"".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant("hello"))
        #expect(value.valueType, .atom(.string))
    }
    func testDecodeCoalescedBool() throws {
        let data = "true".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(true))
        #expect(value.valueType, .atom(.bool))
    }
    
    func testDecodeCoalescedIntArray() throws {
        let data = "[12, 34]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([12, 34]))
        #expect(value.valueType, .array(.int))
    }
    
    func testDecodeCoalescedDoubleArray() throws {
        let data = "[12.3, 4.5]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([12.3, 4.5]))
        #expect(value.valueType, .array(.double))
    }
    func testDecodeCoalescedStringArray() throws {
        let data = "[\"hello\", \"there\"]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant(["hello", "there"]))
        #expect(value.valueType, .array(.string))
    }
    func testDecodeCoalescedBoolArray() throws {
        let data = "[true, false, true]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([true, false, true]))
        #expect(value.valueType, .array(.bool))
    }
    func testDecodeCoalescedMixedDoubleArray() throws {
        let data = "[10, 20, 30.4]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([10, 20, 30.4]))
        #expect(value.valueType, .array(.double))
    }
    func testDecodeCoalescedPointArray() throws {
        let data = "[[10, 20], [30, 40]]".data(using:.utf8)!
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        let value = try decoder.decode(Variant.self, from: data)
        
        #expect(value, Variant([Point(x:10, y:20), Point(x:30, y:40)]))
        #expect(value.valueType, .array(.point))
    }
    
    // Test invalid point value
    // Test invalid values
}
*/
