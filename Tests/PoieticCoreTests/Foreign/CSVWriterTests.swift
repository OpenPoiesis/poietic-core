//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 12/09/2023.
//

import XCTest
@testable import PoieticCore

final class CSVFormatterTests: XCTestCase {
    func testQuoteEmpty() throws {
        let formatter = CSVFormatter()
        XCTAssertEqual(formatter.quote(""), "")
    }
    func testQuoteNotNeeded() throws {
        let formatter = CSVFormatter()
        XCTAssertEqual(formatter.quote("10"), "10")
        XCTAssertEqual(formatter.quote("abc"), "abc")
        XCTAssertEqual(formatter.quote("one two"), "one two")
        XCTAssertEqual(formatter.quote("-"), "-")
        XCTAssertEqual(formatter.quote(" "), " ")
    }
    func testQuoteQuote() throws {
        let formatter = CSVFormatter()
        // Single quote yields four:
        //
        //   original----+
        //               v
        //             """"
        //   opening --^^ ^
        //              | |
        //   escaping---+ +---- closing
        XCTAssertEqual(formatter.quote("\""), "\"\"\"\"")
        XCTAssertEqual(formatter.quote("middle\"quote"), "\"middle\"\"quote\"")
        XCTAssertEqual(formatter.quote("\n"), "\"\n\"")
    }
    func testQuoteSeparators() throws {
        let formatter = CSVFormatter()
        
        XCTAssertEqual(formatter.quote("one,two"), "\"one,two\"")
        XCTAssertEqual(formatter.quote("new\nline"), "\"new\nline\"")
    }
    func testFormatRowEmpty() throws {
        let formatter = CSVFormatter()
        XCTAssertEqual(formatter.format([]), "")
    }
    func testFormatRow() throws {
        let formatter = CSVFormatter()
        XCTAssertEqual(formatter.format(["one","two"]), "one,two")
    }
    func testFormatRowQuote() throws {
        let formatter = CSVFormatter()
        XCTAssertEqual(formatter.format(["one,two","three"]),
                       "\"one,two\",three")
    }
}
