//
//  CSVWriterTests.swift
//
//
//  Created by Stefan Urbanek on 12/09/2023.
//

import Testing
@testable import PoieticCore

@Suite struct CSVFormatterTests {
    @Test func testQuoteEmpty() throws {
        let formatter = CSVFormatter()
        #expect(formatter.quote("") == "")
    }
    @Test func testQuoteNotNeeded() throws {
        let formatter = CSVFormatter()
        #expect(formatter.quote("10") == "10")
        #expect(formatter.quote("abc") == "abc")
        #expect(formatter.quote("one two") == "one two")
        #expect(formatter.quote("-") == "-")
        #expect(formatter.quote(" ") == " ")
    }
    @Test func testQuoteQuote() throws {
        let formatter = CSVFormatter()
        // Single quote yields four:
        //
        //   original----+
        //               v
        //             """"
        //   opening --^^ ^
        //              | |
        //   escaping---+ +---- closing
        #expect(formatter.quote("\"") == "\"\"\"\"")
        #expect(formatter.quote("middle\"quote") == "\"middle\"\"quote\"")
        #expect(formatter.quote("\n") == "\"\n\"")
    }
    @Test func testQuoteSeparators() throws {
        let formatter = CSVFormatter()
        
        #expect(formatter.quote("one,two") == "\"one,two\"")
        #expect(formatter.quote("new\nline") == "\"new\nline\"")
    }
    @Test func testFormatRowEmpty() throws {
        let formatter = CSVFormatter()
        #expect(formatter.format([]) == "")
    }
    @Test func testFormatRow() throws {
        let formatter = CSVFormatter()
        #expect(formatter.format(["one","two"]) == "one,two")
    }
    @Test func testFormatRowQuote() throws {
        let formatter = CSVFormatter()
        #expect(formatter.format(["one,two","three"]) == "\"one,two\",three")
    }
}
