//
//  CSVReaderTests.swift
//
//  Created by Stefan Urbanek on 2021/8/31.
//

import Testing
@testable import PoieticCore

@Suite struct CSVReaderTests {
    @Test func testEmptyReader() throws {
        let reader = CSVReader("")
        #expect(reader.nextToken() == .empty)
    }

    @Test func testWhitespaceRows() throws {
        let reader = CSVReader(" ")
        #expect(reader.nextToken() == .value(" "))
        #expect(reader.nextToken() == .empty)
        
        let reader2 = CSVReader("\n")
        #expect(reader2.nextToken() == .recordSeparator)
        #expect(reader2.nextToken() == .empty)
    }
    
    @Test func testRowTokens() throws {
        let reader = CSVReader("one,two,three")

        #expect(reader.nextToken() == .value("one"))
        #expect(reader.nextToken() == .fieldSeparator)
        #expect(reader.nextToken() == .value("two"))
        #expect(reader.nextToken() == .fieldSeparator)
        #expect(reader.nextToken() == .value("three"))
        #expect(reader.nextToken() == .empty)
    }
    @Test func testCustomDelimiters() throws {
        let reader = CSVReader("1@2|10@20",
                               options: CSVOptions(fieldDelimiter:"@", recordDelimiter:"|"))

        #expect(reader.next() == ["1", "2"])
        #expect(reader.next() == ["10", "20"])
    }

    @Test func testQuote() throws {
        let reader = CSVReader("\"quoted\"")
        #expect(reader.nextToken() == .value("quoted"))
        #expect(reader.nextToken() == .empty)
        
        let reader2 = CSVReader("\"quoted,comma\"")
        #expect(reader2.nextToken() == .value("quoted,comma"))
        #expect(reader2.nextToken() == .empty)
        
        let reader3 = CSVReader("\"quoted\nnewline\"")
        #expect(reader3.nextToken() == .value("quoted\nnewline"))
        #expect(reader3.nextToken() == .empty)
    }

    @Test func testQuoteEscape() throws {
        let reader = CSVReader("\"\"\"\"")
        #expect(reader.nextToken() == .value("\""))
        #expect(reader.nextToken() == .empty)
    }
    
    @Test func testWeirdQuote() throws {
        // The following behavior was observed with Numbers and with MS Word
        // This is broken but should be parsed into a signle quote value

        let reader = CSVReader("\"\"\"")
        #expect(reader.nextToken() == .value("\""))
        #expect(reader.nextToken() == .empty)

        // This is broken but should be parsed into a signle quote value
        let reader2 = CSVReader("\"quoted\" value")
        #expect(reader2.nextToken() == .value("quoted value"))
        #expect(reader2.nextToken() == .empty)
    }
    
    @Test func testRow() throws {
        let reader = CSVReader("one,two,three")
        #expect(reader.next() == ["one", "two", "three"])
        #expect(reader.next() == nil)
    }

    @Test func testQuotedRow() throws {
        let reader = CSVReader("one,\"quoted value\",three")
        #expect(reader.next() == ["one", "quoted value", "three"])
    }

    @Test func testMultipleRows() throws {
        let reader = CSVReader("11,12,13\n21,22,23\n31,32,33")

        #expect(reader.next() == ["11", "12", "13"])
        #expect(reader.next() == ["21", "22", "23"])
        #expect(reader.next() == ["31", "32", "33"])
    }
}
