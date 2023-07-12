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
        XCTAssertEqual(try ForeignValue("10").intValue(), 10)
        // TODO: Accept underscore in numeric values
//        XCTAssertEqual(try ForeignValue("1_0_0").intValue(), 100)

        XCTAssertThrowsError(try ForeignValue("10x").intValue())
        XCTAssertThrowsError(try ForeignValue("").intValue())
    }
    func testDoubleFromString() throws {
        let value1 = try ForeignValue("3.14e2").doubleValue()
        XCTAssertEqual(value1, 3.14e2)

        XCTAssertThrowsError(try ForeignValue("10x").doubleValue())
        XCTAssertThrowsError(try ForeignValue("").doubleValue())
    }
    func testBoolFromString() throws {
        let value1 = try ForeignValue("true").boolValue()
        XCTAssertEqual(value1, true)

        let value2 = try ForeignValue("false").boolValue()
        XCTAssertEqual(value2, false)
        
        XCTAssertThrowsError(try ForeignValue("something").boolValue())
        XCTAssertThrowsError(try ForeignValue("").boolValue())
    }
    func testPointFromString() throws {
        XCTAssertEqual(try ForeignValue("1.2x3.4").pointValue(), Point(x:1.2, y:3.4))
        // TODO: Accept underscore in numeric values
//        XCTAssertEqual(try ForeignValue("1_0_0").intValue(), 100)

        XCTAssertThrowsError(try ForeignValue("10 x 20").pointValue())
        XCTAssertThrowsError(try ForeignValue("10x").pointValue())
        XCTAssertThrowsError(try ForeignValue("x10").pointValue())
        XCTAssertThrowsError(try ForeignValue("x").pointValue())
        XCTAssertThrowsError(try ForeignValue("").intValue())
    }
    func testStringToPoint() throws {
        XCTAssertEqual(try ForeignValue(Point(x:1.0, y:2.0)).stringValue(), "1.0x2.0")
    }
    
    func testTwoItemArrayIsAPointConvertible() throws {
        XCTAssertEqual(try ForeignValue([1, 2]).pointValue(), Point(1.0, 2.0))

    }

}

final class ForeignValueJSONTests: XCTestCase {
    func testAtomFromJSON() throws {
        // TODO: Int should be int
        XCTAssertEqual(try ForeignAtom.fromJSON("10").valueType, .double)
        XCTAssertEqual(try ForeignAtom.fromJSON("10.0").valueType, .double)
        XCTAssertEqual(try ForeignAtom.fromJSON("true").valueType, .bool)
        XCTAssertEqual(try ForeignAtom.fromJSON("\"hello\"").valueType, .string)
        XCTAssertEqual(try ForeignAtom.fromJSON("[10, 20]").valueType, .point)
    }
    
    func testAtomToJSON() throws {
        // TODO: Int should be int
        XCTAssertEqual(try ForeignAtom(10).toJSON(), "10")
        XCTAssertEqual(try ForeignAtom(10.1).toJSON(), "10.1")
        XCTAssertEqual(try ForeignAtom(true).toJSON(), "true")
        XCTAssertEqual(try ForeignAtom("hello").toJSON(), "\"hello\"")
        XCTAssertEqual(try ForeignAtom(Point(10, 20)).toJSON(), "[10,20]")
    }
    
    
    func testValueFromJSON() throws {
        // TODO: Int should be int
        XCTAssertEqual(try ForeignValue.fromJSON("10").valueType, .double)
        XCTAssertEqual(try ForeignValue.fromJSON("10.0").valueType, .double)
        XCTAssertEqual(try ForeignValue.fromJSON("true").valueType, .bool)
        XCTAssertEqual(try ForeignValue.fromJSON("\"hello\"").valueType, .string)
//        XCTAssertEqual(try ForeignValue.fromJSON("[10, 20]").valueType, .point)

        XCTAssertEqual(try ForeignValue.fromJSON("[10, 20]").arrayItemType, .double)
        XCTAssertEqual(try ForeignValue.fromJSON("[\"a\", \"b\"]").arrayItemType, .string)
        XCTAssertEqual(try ForeignValue.fromJSON("[[10, 20], [30, 40]]").arrayItemType, .point)

        XCTAssertThrowsError(try ForeignValue.fromJSON("[\"a\", 10]"))
    }
}
