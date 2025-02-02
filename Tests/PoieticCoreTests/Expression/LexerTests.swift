//
//  LexerTests.swift
//
//
//  Created by Stefan Urbanek on 01/07/2022.
//

import Testing
@testable import PoieticCore

@Suite struct LexerTests {
    @Test func acceptFunction() throws {
        var lexer = ExpressionLexer(string: " ")
        #expect(lexer.peek() == " ")
        lexer.advance()
        #expect(lexer.peek() == nil)
        #expect(lexer.atEnd)
    }
    
    @Test func emptyString() throws {
        var lexer = ExpressionLexer(string: "")
        
        #expect(lexer.atEnd)
        #expect(lexer.next().type == .empty)
        #expect(lexer.next().type == .empty)
    }
    
    @Test func spaceOnly() throws {
        var lexer = ExpressionLexer(string: " ")
        
        #expect(!lexer.atEnd)
        #expect(lexer.next().type == .empty)
        #expect(lexer.atEnd)
    }

    // MARK: Numbers
    
    @Test func integerToken() throws {
        var lexer = ExpressionLexer(string: "1234")
        let token = lexer.next()

        #expect(token.type == .int)
        #expect(token.text == "1234")
    }
    
    @Test func thousandsSeparator() throws {
        var lexer = ExpressionLexer(string: "123_456_789")
        let token = lexer.next()
        
        #expect(token.type == .int)
        #expect(token.text == "123_456_789")
    }
    
    @Test func multipleInts() throws {
        var lexer = ExpressionLexer(string: "1 22 333 ")
        var token = lexer.next()
        
        #expect(token.type == .int)
        #expect(token.text == "1")
        
        token = lexer.next()
        #expect(token.type == .int)
        #expect(token.text == "22")
        
        token = lexer.next()
        #expect(token.type == .int)
        #expect(token.text == "333")
    }
    
    @Test func invalidInteger() throws {
        var lexer = ExpressionLexer(string: "1234x")
        let token = lexer.next()
        #expect(token.type == .error(.invalidCharacterInNumber))
        #expect(token.text == "1234x")
    }
    
    @Test func floatTokens() throws {
        var lexer = ExpressionLexer(string: "10.20 10e20 10.20e30 10.20e-30 10E23 1E+5")
        var token = lexer.next()
        #expect(token.type == .double)
        #expect(token.text == "10.20")
        
        token = lexer.next()
        #expect(token.type == .double)
        #expect(token.text == "10e20")
        
        token = lexer.next()
        #expect(token.type == .double)
        #expect(token.text == "10.20e30")
        
        token = lexer.next()
        #expect(token.type == .double)
        #expect(token.text == "10.20e-30")

        token = lexer.next()
        #expect(token.type == .double)
        #expect(token.text == "10E23")

        token = lexer.next()
        #expect(token.type == .double)
        #expect(token.text == "1E+5")
    }
    
    @Test func invalidFloat() throws {
        var lexer = ExpressionLexer(string: "1. 2.x 3ex")
        
        var token = lexer.next()
        #expect(token.type == .error(.invalidCharacterInNumber))
        #expect(token.text == "1. ")
        
        
        token = lexer.next()
        #expect(token.type == .error(.invalidCharacterInNumber))
        #expect(token.text == "2.x")
        
        token = lexer.next()
        #expect(token.type == .error(.invalidCharacterInNumber))
        #expect(token.text == "3ex")
    }
    
    
    @Test func identifierToken() throws {
        var lexer = ExpressionLexer(string: "an_identifier_1 _underscore")
        var token = lexer.next()
        #expect(token.type == .identifier)
        #expect(token.text == "an_identifier_1")

        token = lexer.next()
        #expect(token.type == .identifier)
        #expect(token.text == "_underscore")
    }
    
    // MARK: Punctuation and operators
    
    @Test func punctuationToken() throws {
        var lexer = ExpressionLexer(string: "( , )")
        
        var token = lexer.next()
        #expect(token.type == .leftParen)
        #expect(token.text == "(")
        
        token = lexer.next()
        #expect(token.type == .comma)
        #expect(token.text == ",")
        
        token = lexer.next()
        #expect(token.type == .rightParen)
        #expect(token.text == ")")
    }
    
    @Test func operatorToken() throws {
        var lexer = ExpressionLexer(string: "+ - * / %")
        
        var token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "+")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "-")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "*")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "/")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "%")
    }
    @Test func comparisonOperator() throws {
        var lexer = ExpressionLexer(string: "> >= < <= == != !")
        
        var token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == ">")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == ">=")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "<")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "<=")
        
        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "==")

        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "!=")

        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "!")
    }

    @Test func minus() throws {
        var lexer = ExpressionLexer(string: "1-2- 3")
        var token = lexer.next()
        #expect(token.type == .int)
        #expect(token.text == "1")
        
        token = lexer.next()
        #expect(token.type == .int)
        #expect(token.text == "-2")

        token = lexer.next()
        #expect(token.type == .operator)
        #expect(token.text == "-")

        token = lexer.next()
        #expect(token.type == .int)
        #expect(token.text == "3")
    }
    
    // MARK: Trivia
    
    @Test func emptyTrivia() throws {
        var lexer = ExpressionLexer(string: "   ")
        let token = lexer.next()
        #expect(token.type == .empty)
        #expect(token.text == "")
        #expect(token.fullText == "   ")
    }
    
    @Test func trailingTrivia() throws {
        var lexer = ExpressionLexer(string: "thing   ")
        let token = lexer.next()
        #expect(token.type == .identifier)
        #expect(token.text == "thing")
        #expect(token.trailingTrivia == "   ")
    }
    
    @Test func trailingTriviaComment() throws {
        var lexer = ExpressionLexer(string: "thing   # This\nThat")
        let token = lexer.next()
        #expect(token.type == .identifier)
        #expect(token.text == "thing")
        #expect(token.trailingTrivia == "   # This")
    }
    @Test func leadingTriviaComment() throws {
        var lexer = ExpressionLexer(string: "# Comment\nthing")
        let token = lexer.next()
        #expect(token.type == .identifier)
        #expect(token.text == "thing")
        #expect(token.leadingTrivia == "# Comment\n")
    }

}

