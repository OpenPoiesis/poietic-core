//
//  CSVReaderTests.swift
//
//  Created by Stefan Urbanek on 2021/8/31.
//

import Testing
@testable import PoieticCore

@Suite struct CSVReaderTests {
    @Test func emptyReader() throws {
        let reader = CSVReader("")
        #expect(reader.next() == nil)
    }

    @Test func whitespaceRow() throws {
        let reader = CSVReader(" ")
        #expect(reader.next() == [" "])
        #expect(reader.next() == nil)

        let reader2 = CSVReader("\n")
        #expect(reader2.next() == [""])
        #expect(reader2.next() == nil)
    }
    
    @Test func regularRow() throws {
        let reader = CSVReader("one,two,three")

        #expect(reader.next() == ["one", "two", "three"])
        #expect(reader.next() == nil)
    }
    @Test func customDelimiters() throws {
        let reader = CSVReader("1@2|10@20",
                               options: CSVOptions(fieldDelimiter:"@", recordDelimiter:"|"))

        #expect(reader.next() == ["1", "2"])
        #expect(reader.next() == ["10", "20"])
    }
    @Test func quotedField() throws {
        let reader = CSVReader("\"quoted\"")
        #expect(reader.next() == ["quoted"])
        #expect(reader.next() == nil)
        
        let reader2 = CSVReader("\"quoted,comma\"")
        #expect(reader2.next() == ["quoted,comma"])
        #expect(reader2.next() == nil)
        
        let reader3 = CSVReader("\"quoted\nnewline\"")
        #expect(reader3.next() == ["quoted\nnewline"])
        #expect(reader3.next() == nil)
    }

    @Test func testQuoteEscape() throws {
        let reader = CSVReader("\"\"\"\"")
        #expect(reader.next() == ["\""])
        #expect(reader.next() == nil)
    }

    @Test func quoteInTheMiddle() throws {
        let reader = CSVReader("a \" b,")
        #expect(reader.next() == ["a \" b",""])
        #expect(reader.next() == nil)

    }
    
    @Test func earlyQuoteFinish() throws {
        // The following behaviour was observed with Numbers and with MS Word
        // This is broken but should be parsed into a single quote value

        let reader = CSVReader("\"\"\"")
        #expect(reader.next() == ["\""])
        #expect(reader.next() == nil)

        let reader2 = CSVReader("\"quoted\" value")
        #expect(reader2.next() == ["quoted value"])
        #expect(reader2.next() == nil)

        let reader3 = CSVReader("\"quoted\" one \" two \"\"")
        #expect(reader3.next() == ["quoted one \" two \""])
        #expect(reader3.next() == nil)

        let reader4 = CSVReader("\"quoted\" open \",")
        #expect(reader4.next() == ["quoted open \"", ""])
        #expect(reader4.next() == nil)
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
