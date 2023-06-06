//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 01/07/2022.
//

import XCTest
@testable import Poietic

final class LexerTests: XCTestCase {
    func testAcceptFunction() throws {
        // TODO: This is a scanner test. (originally it was in the lexer)
        let lexer = Lexer(string: " ")
        XCTAssertNotNil(lexer.scanner.currentChar)
        XCTAssertTrue(lexer.scanner.accept(\.isWhitespace))
        XCTAssertNil(lexer.scanner.currentChar)
        XCTAssertTrue(lexer.scanner.atEnd)
    }
    
    func testEmpty() throws {
        let lexer = Lexer(string: "")
        
        XCTAssertTrue(lexer.atEnd)
        XCTAssertEqual(lexer.next().type, TokenType.empty)
        lexer.advance()
        XCTAssertTrue(lexer.atEnd)
        XCTAssertEqual(lexer.next().type, TokenType.empty)
    }

    func testSpace() throws {
        let lexer = Lexer(string: " ")
        
        XCTAssertFalse(lexer.atEnd)
        XCTAssertEqual(lexer.next().type, TokenType.empty)
        XCTAssertTrue(lexer.atEnd)
    }
    func testUnexpected() throws {
        let lexer = Lexer(string: "$")
        let token = lexer.next()

        XCTAssertEqual(token.type, TokenType.error(.unexpectedCharacter))
        XCTAssertEqual(token.text, "$")
    }

    // MARK: Numbers
    
    func testInteger() throws {
        let lexer = Lexer(string: "1234")
        let token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "1234")
    }

    func testThousandsSeparator() throws {
        let lexer = Lexer(string: "123_456_789")
        let token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "123_456_789")
    }

    func testMultipleInts() throws {
        let lexer = Lexer(string: "1 22 333 ")
        var token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "1")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "22")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "333")
    }

    func testInvalidInteger() throws {
        let lexer = Lexer(string: "1234x")
        let token = lexer.next()
        XCTAssertEqual(token.type, TokenType.error(.invalidCharacterInNumber))
        XCTAssertEqual(token.text, "1234x")
    }

    func testFloat() throws {
        let lexer = Lexer(string: "10.20 10e20 10.20e30 10.20e-30")
        var token = lexer.next()
        XCTAssertEqual(token.type, TokenType.float)
        XCTAssertEqual(token.text, "10.20")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.float)
        XCTAssertEqual(token.text, "10e20")
        
        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.float)
        XCTAssertEqual(token.text, "10.20e30")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.float)
        XCTAssertEqual(token.text, "10.20e-30")
    }


    func testIdentifier() throws {
        let lexer = Lexer(string: "an_identifier_1")
        let token = lexer.next()
        XCTAssertEqual(token.type, TokenType.identifier)
        XCTAssertEqual(token.text, "an_identifier_1")
    }

    // MARK: Punctuation and operators
    
    func testPunctuation() throws {
        let lexer = Lexer(string: "( , )")

        var token = lexer.next()
        XCTAssertEqual(token.type, TokenType.leftParen)
        XCTAssertEqual(token.text, "(")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.comma)
        XCTAssertEqual(token.text, ",")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.rightParen)
        XCTAssertEqual(token.text, ")")
    }
    
    func testOperator() throws {
        let lexer = Lexer(string: "+ - * / %")

        var token = lexer.next()
        XCTAssertEqual(token.type, TokenType.operator)
        XCTAssertEqual(token.text, "+")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.operator)
        XCTAssertEqual(token.text, "-")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.operator)
        XCTAssertEqual(token.text, "*")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.operator)
        XCTAssertEqual(token.text, "/")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.operator)
        XCTAssertEqual(token.text, "%")
    }

    func testMinusAsOperator() throws {
        let lexer = Lexer(string: "1-2")
        var token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "1")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.operator)
        XCTAssertEqual(token.text, "-")

        token = lexer.next()
        XCTAssertEqual(token.type, TokenType.int)
        XCTAssertEqual(token.text, "2")
    }
    
    // MARK: Trivia
    
    func testEmptyTrivia() throws {
        let lexer = Lexer(string: "   ")
        let token = lexer.next()
        XCTAssertEqual(token.type, TokenType.empty)
        XCTAssertEqual(token.text, "")
        XCTAssertEqual(token.fullText, "   ")
    }
    
    func testTrailingTrivia() throws {
        let lexer = Lexer(string: "thing   ")
        let token = lexer.next()
        XCTAssertEqual(token.type, TokenType.identifier)
        XCTAssertEqual(token.text, "thing")
        XCTAssertEqual(token.trailingTrivia, "   ")
    }
}

