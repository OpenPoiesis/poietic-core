//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 13/03/2025.
//

import Testing
@testable import PoieticCore


@Suite struct TestLexer {
    
    @Test func empty() async throws {
        var lexer = EDNLexer(string: "")
        #expect(lexer.next() == nil)
    }
    
    @Test func emptyWhitespace() async throws {
        var lexer = EDNLexer(string: "  ")
        #expect(lexer.next() == nil)
    }
    
    @Test func delimiters() async throws {
        var lexer = EDNLexer(string: "( ) ,")
        #expect(lexer.next() == EDNLexer.Token(.leftParen, "("))
        #expect(lexer.next() == EDNLexer.Token(.rightParen, ")"))
        #expect(lexer.next() == EDNLexer.Token(.comma, ","))
        #expect(lexer.next() == nil)
    }
    @Test func strings() async throws {
        var lexer = EDNLexer(string: "\"\" \"hello\"")
        #expect(lexer.next() == EDNLexer.Token(.string, ""))
        #expect(lexer.next() == EDNLexer.Token(.string, "hello"))
        #expect(lexer.next() == nil)
    }
    @Test func symbol() async throws {
        var lexer = EDNLexer(string: "name this-that")
        #expect(lexer.next() == EDNLexer.Token(.symbol, "name"))
        #expect(lexer.next() == EDNLexer.Token(.symbol, "this-that"))
        #expect(lexer.next() == nil)
    }
    @Test func keyword() async throws {
        var lexer = EDNLexer(string: ":node")
        #expect(lexer.next() == EDNLexer.Token(.keyword, ":node"))
        #expect(lexer.next() == nil)
    }
    @Test func stringEscape() async throws {
        var lexer = EDNLexer(string: "\"quo\\\"te\"")
        let optionalToken = lexer.next()
        let token = try #require(optionalToken)
        #expect(token == EDNLexer.Token(.string, "quo\\\"te"))
        #expect(unescape(token.text) == "quo\"te")
        #expect(lexer.next() == nil)
    }
    @Test func int() async throws {
        var lexer = EDNLexer(string: "0 10 -5")
        #expect(lexer.next() == EDNLexer.Token(.int, "0"))
        #expect(lexer.next() == EDNLexer.Token(.int, "10"))
        #expect(lexer.next() == EDNLexer.Token(.int, "-5"))
        #expect(lexer.next() == nil)
    }
    @Test func float() async throws {
        var lexer = EDNLexer(string: "0.0 10e2 -1.2e-3")
        #expect(lexer.next() == EDNLexer.Token(.float, "0.0"))
        #expect(lexer.next() == EDNLexer.Token(.float, "10e2"))
        #expect(lexer.next() == EDNLexer.Token(.float, "-1.2e-3"))
        #expect(lexer.next() == nil)
    }
    @Test func unescapeString() async throws {
        #expect(unescape("") == "")
        #expect(unescape("abc") == "abc")
        #expect(unescape("\\t") == "\t")
        #expect(unescape("\\n") == "\n")
        #expect(unescape("\\r") == "\r")
        #expect(unescape("\\0") == "\0")
        #expect(unescape("\\\"") == "\"")
        #expect(unescape("\\\'") == "\'")
    }
    
    @Test func asEDNValue() async throws {
        var lexer = EDNLexer(string: "true false 10 symbol :keyword \"text\"")
        #expect(lexer.next()?.asEDNValue() == .bool(true))
        #expect(lexer.next()?.asEDNValue() == .bool(false))
        #expect(lexer.next()?.asEDNValue() == .int(10))
        #expect(lexer.next()?.asEDNValue() == .symbol("symbol"))
        #expect(lexer.next()?.asEDNValue() == .keyword(":keyword"))
        #expect(lexer.next()?.asEDNValue() == .string("text"))
    }
    
    @Test func unexpectedCharacter() async throws {
        var lexer = EDNLexer(string: "-a")
        #expect(lexer.next() == EDNLexer.Token(.error(.unexpectedCharacter), "-"))
    }
    @Test func unexpectedCharacter2() async throws {
        var lexer = EDNLexer(string: "$")
        #expect(lexer.next() == EDNLexer.Token(.error(.unexpectedCharacter), "$"))
    }
    @Test func unexpectedEndOfString() async throws {
        var lexer = EDNLexer(string: "\"text")
        #expect(lexer.next()?.type == .error(.unexpectedEndOfString))
    }
    @Test func unexpectedEndOfStringEscape() async throws {
        var lexer = EDNLexer(string: "\"text\\")
        #expect(lexer.next()?.type == .error(.unexpectedEndOfString))
    }
    @Test func invalidCharacterInNumber() async throws {
        var lexer = EDNLexer(string: "12a")
        #expect(lexer.next() == EDNLexer.Token(.error(.invalidCharacterInNumber), "12a"))
    }
    @Test func numberExpected() async throws {
        var lexer = EDNLexer(string: "12.a")
        #expect(lexer.next() == EDNLexer.Token(.error(.invalidCharacterInNumber), "12.a"))
    }

}

@Suite struct TestParser {
    @Test func empty() async throws {
        var parser = EDNParser(string: "")
        #expect(try parser.next() == nil)
    }
    @Test func atoms() async throws {
        var parser = EDNParser(string: "true 10 \"text\" 1.5")
        #expect(try parser.next() == EDNValue.bool(true))
        #expect(try parser.next() == EDNValue.int(10))
        #expect(try parser.next() == EDNValue.string("text"))
        #expect(try parser.next() == EDNValue.float(1.5))
        #expect(try parser.next() == nil)
    }

    @Test func emptyList() async throws {
        var parser = EDNParser(string: "()")
        #expect(try parser.next() == EDNValue.list([]))
        #expect(try parser.next() == nil)

    }
    @Test func lists() async throws {
        var parser = EDNParser(string: "(1 2 3) (true false)")
        #expect(try parser.next() == EDNValue.list([.int(1), .int(2), .int(3)]))
        #expect(try parser.next() == EDNValue.list([.bool(true), .bool(false)]))
        #expect(try parser.next() == nil)
    }

    @Test func nestedList() async throws {
        var parser = EDNParser(string: "(1 2 3 (true false))")
        #expect(try parser.next() == EDNValue.list([.int(1), .int(2), .int(3), .list([.bool(true), .bool(false)])]))
        #expect(try parser.next() == nil)
    }

    @Test func unexpectedListEnd() async throws {
        var parser = EDNParser(string: ")")
        #expect {
            try parser.next()
        } throws: {
            guard let error = $0 as? EDNParser.ParserError else {
                return false
            }
            return error.error == .unexpectedListEnd
        }
    }
    @Test func unexpectedComma() async throws {
        var parser = EDNParser(string: ",")
        #expect {
            try parser.next()
        } throws: {
            guard let error = $0 as? EDNParser.ParserError else {
                return false
            }
            return error.error == .unexpectedComma
        }
    }
    @Test func unexpectedEndOfList() async throws {
        var parser = EDNParser(string: "(1 2 3")
        #expect {
            try parser.next()
        } throws: {
            guard let error = $0 as? EDNParser.ParserError else {
                return false
            }
            return error.error == .unexpectedEndOfList
        }
    }
    @Test func invalidNumber() async throws {
        var parser = EDNParser(string: "92233720368547758070")
        #expect {
            try parser.next()
        } throws: {
            guard let error = $0 as? EDNParser.ParserError else {
                return false
            }
            return error.error == .invalidNumber
        }
    }
}
