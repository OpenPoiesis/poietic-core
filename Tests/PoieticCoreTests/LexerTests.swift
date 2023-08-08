//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 01/07/2022.
//

import XCTest
@testable import PoieticCore

final class LexerTests: XCTestCase {
    func testAcceptFunction() throws {
        // TODO: This is a scanner test. (originally it was in the lexer)
        let lexer = ExpressionLexer(string: " ")
        XCTAssertNotNil(lexer.scanner.currentChar)
        XCTAssertTrue(lexer.scanner.scan(\.isWhitespace))
        XCTAssertNil(lexer.scanner.currentChar)
        XCTAssertTrue(lexer.scanner.atEnd)
    }
    
    func testEmpty() throws {
        var lexer = ExpressionLexer(string: "")
        
        XCTAssertTrue(lexer.atEnd)
        XCTAssertEqual(lexer.next().type, ExpressionTokenType.empty)
        XCTAssertEqual(lexer.next().type, ExpressionTokenType.empty)
    }
    
    func testSpace() throws {
        var lexer = ExpressionLexer(string: " ")
        
        XCTAssertFalse(lexer.atEnd)
        XCTAssertEqual(lexer.next().type, ExpressionTokenType.empty)
        XCTAssertTrue(lexer.atEnd)
    }
    //    func testUnexpected() throws {
    //        var lexer = ExpressionLexer(string: "$")
    //        let token = lexer.next()
    //
    //        XCTAssertEqual(token.type, ExpressionTokenType.error(.unexpectedCharacter))
    //        XCTAssertEqual(token.text, "$")
    //    }
    
    // MARK: Numbers
    
    func testInteger() throws {
        var lexer = ExpressionLexer(string: "1234")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "1234")
    }
    
    func testThousandsSeparator() throws {
        var lexer = ExpressionLexer(string: "123_456_789")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "123_456_789")
    }
    
    func testMultipleInts() throws {
        var lexer = ExpressionLexer(string: "1 22 333 ")
        var token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "1")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "22")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "333")
    }
    
    func testInvalidInteger() throws {
        var lexer = ExpressionLexer(string: "1234x")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.error(.invalidCharacterInNumber))
        XCTAssertEqual(token.text, "1234x")
    }
    
    func testFloat() throws {
        var lexer = ExpressionLexer(string: "10.20 10e20 10.20e30 10.20e-30")
        var token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.double)
        XCTAssertEqual(token.text, "10.20")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.double)
        XCTAssertEqual(token.text, "10e20")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.double)
        XCTAssertEqual(token.text, "10.20e30")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.double)
        XCTAssertEqual(token.text, "10.20e-30")
    }
    
    func testInvalidFloat() throws {
        var lexer = ExpressionLexer(string: "1. 2.x 3ex")
        
        var token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.error(.numberExpected))
        XCTAssertEqual(token.text, "1. ")
        
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.error(.numberExpected))
        XCTAssertEqual(token.text, "2.x")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.error(.numberExpected))
        XCTAssertEqual(token.text, "3ex")
    }
    
    
    func testIdentifier() throws {
        var lexer = ExpressionLexer(string: "an_identifier_1")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.identifier)
        XCTAssertEqual(token.text, "an_identifier_1")
    }
    
    // MARK: Punctuation and operators
    
    func testPunctuation() throws {
        var lexer = ExpressionLexer(string: "( , )")
        
        var token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.leftParen)
        XCTAssertEqual(token.text, "(")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.comma)
        XCTAssertEqual(token.text, ",")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.rightParen)
        XCTAssertEqual(token.text, ")")
    }
    
    func testOperator() throws {
        var lexer = ExpressionLexer(string: "+ - * / %")
        
        var token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.operator)
        XCTAssertEqual(token.text, "+")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.operator)
        XCTAssertEqual(token.text, "-")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.operator)
        XCTAssertEqual(token.text, "*")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.operator)
        XCTAssertEqual(token.text, "/")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.operator)
        XCTAssertEqual(token.text, "%")
    }
    
    func testMinusAsOperator() throws {
        var lexer = ExpressionLexer(string: "1-2")
        var token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "1")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.operator)
        XCTAssertEqual(token.text, "-")
        
        token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.int)
        XCTAssertEqual(token.text, "2")
    }
    
    // MARK: Trivia
    
    func testEmptyTrivia() throws {
        var lexer = ExpressionLexer(string: "   ")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.empty)
        XCTAssertEqual(token.text, "")
        XCTAssertEqual(token.fullText, "   ")
    }
    
    func testTrailingTrivia() throws {
        var lexer = ExpressionLexer(string: "thing   ")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.identifier)
        XCTAssertEqual(token.text, "thing")
        XCTAssertEqual(token.trailingTrivia, "   ")
    }
    
    func testTrailingTriviaComment() throws {
        var lexer = ExpressionLexer(string: "thing   # This\nThat")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.identifier)
        XCTAssertEqual(token.text, "thing")
        XCTAssertEqual(token.trailingTrivia, "   # This")
    }
    func testLeadingTriviaComment() throws {
        var lexer = ExpressionLexer(string: "# Comment\nthing")
        let token = lexer.next()
        XCTAssertEqual(token.type, ExpressionTokenType.identifier)
        XCTAssertEqual(token.text, "thing")
        XCTAssertEqual(token.leadingTrivia, "# Comment\n")
    }

}

