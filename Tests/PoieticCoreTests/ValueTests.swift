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

}
