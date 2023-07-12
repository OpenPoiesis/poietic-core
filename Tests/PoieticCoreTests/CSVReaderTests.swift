//
//  CSVReaderTests.swift
//
//  Created by Stefan Urbanek on 2021/8/31.
//

import XCTest
@testable import PoieticCore

final class CSVFormatterTests: XCTestCase {
    func testEmpty() throws {
        let formatter = CSVFormatter()
        
        XCTAssertEqual(formatter.quote(""), "")
    }

    func testEscapeQuote() throws {
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
    }

    func testQuoteSeparators() throws {
        let formatter = CSVFormatter()
        
        XCTAssertEqual(formatter.quote("one,two"), "\"one,two\"")
        XCTAssertEqual(formatter.quote("new\nline"), "\"new\nline\"")
    }

    func testNoNeedToQuote() throws {
        let formatter = CSVFormatter()
        
        XCTAssertEqual(formatter.quote(" "), " ")
        XCTAssertEqual(formatter.quote("one two"), "one two")
    }
}

final class CSVReaderTests: XCTestCase {
    func testEmptyReader() throws {
        var reader:CSVReader
        var token: CSVReader.Token
        
        reader = CSVReader("")
        token = reader.nextToken()
        
        XCTAssertEqual(token, .empty)
    }

    func testWhitespaceRows() throws {
        var reader:CSVReader
        var token: CSVReader.Token
        
        reader = CSVReader(" ")
        token = reader.nextToken()
        XCTAssertEqual(token, .value(" "))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
        
        reader = CSVReader("\n")
        token = reader.nextToken()
        XCTAssertEqual(token, .recordSeparator)
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
    }
    
    func testRowTokens() throws {
        var reader:CSVReader
        var token: CSVReader.Token
        
        reader = CSVReader("one,two,three")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("one"))
        token = reader.nextToken()
        XCTAssertEqual(token, .fieldSeparator)
        token = reader.nextToken()
        XCTAssertEqual(token, .value("two"))
        token = reader.nextToken()
        XCTAssertEqual(token, .fieldSeparator)
        token = reader.nextToken()
        XCTAssertEqual(token, .value("three"))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
    }
    func testCustomDelimiters() throws {
        var reader = CSVReader("1@2|10@20",
                               options: CSVOptions(fieldDelimiter:"@",
                                                          recordDelimiter:"|"))

        let row1 = reader.next()
        XCTAssertEqual(row1, ["1", "2"])

        let row2 = reader.next()
        XCTAssertEqual(row2, ["10", "20"])
    }

    func testQuote() throws {
        var reader:CSVReader
        var token: CSVReader.Token
        
        reader = CSVReader("\"quoted\"")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("quoted"))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
        
        reader = CSVReader("\"quoted,comma\"")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("quoted,comma"))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
        
        reader = CSVReader("\"quoted\nnewline\"")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("quoted\nnewline"))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
    }
    func testQuoteEscape() throws {
        var reader:CSVReader
        var token: CSVReader.Token
        
        reader = CSVReader("\"\"\"\"")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("\""))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
    }
    func testWeirdQuote() throws {
        var reader:CSVReader
        var token: CSVReader.Token
        
        // The following behavior was observed with Numbers and with MS Word
        
        // This is broken but should be parsed into a signle quote value
        reader = CSVReader("\"\"\"")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("\""))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)

        // This is broken but should be parsed into a signle quote value
        reader = CSVReader("\"quoted\" value")
        token = reader.nextToken()
        XCTAssertEqual(token, .value("quoted value"))
        token = reader.nextToken()
        XCTAssertEqual(token, .empty)
    }
    
    func testRow() throws {
        var reader: CSVReader
        var row: [String]?
        
        reader = CSVReader("one,two,three")
        row = reader.next()
        
        XCTAssertEqual(row, ["one", "two", "three"])
        XCTAssertNil(reader.next())
    }

    func testQuotedRow() throws {
        var reader: CSVReader
        var row: [String]?
        
        reader = CSVReader("one,\"quoted value\",three")
        row = reader.next()
        
        XCTAssertEqual(row, ["one", "quoted value", "three"])
    }

    func testMultipleRows() throws {
        var reader: CSVReader
        var row: [String]?
        
        reader = CSVReader("11,12,13\n21,22,23\n31,32,33")
        row = reader.next()
        XCTAssertEqual(row, ["11", "12", "13"])
        row = reader.next()
        XCTAssertEqual(row, ["21", "22", "23"])
        row = reader.next()
        XCTAssertEqual(row, ["31", "32", "33"])
    }

}
