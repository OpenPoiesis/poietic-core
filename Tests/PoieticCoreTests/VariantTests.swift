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
