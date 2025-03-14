//
//  EDNParser.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 13/03/2025.
//

struct EDNParser {
    var lexer: EDNLexer
    
    struct ParserError: Error, Equatable {
        let error: EDNSyntaxError
        let location: TextLocation
        init(_ error: EDNSyntaxError, _ location: TextLocation) {
            self.error = error
            self.location = location
        }
    }

    init(string: String) {
        self.lexer = EDNLexer(string: string)
    }

    mutating func next() throws (ParserError) -> EDNValue? {
        guard let token = lexer.next() else {
            return nil
        }
        return try parseValue(token)
    }

    mutating func parseValue(_ token: EDNLexer.Token) throws (ParserError) -> EDNValue {
        switch token.type {
        case .leftParen: return try parseList()
        case .rightParen: throw ParserError(.unexpectedListEnd, lexer.location)
        case .leftBracket: return try parseVector()
        case .rightBracket: throw ParserError(.unexpectedListEnd, lexer.location)
        case .comma: throw ParserError(.unexpectedComma, lexer.location)
        case .error(let error): throw ParserError(error, lexer.location)
        case .float:
            guard let value = Double(String(token.text)) else {
                throw ParserError(.invalidNumber, lexer.location)
            }
            return .float(value)
        case .int:
            guard let value = Int(String(token.text)) else {
                throw ParserError(.invalidNumber, lexer.location)
            }
            return .int(value)
        case .keyword:
            return .keyword(String(token.text))
        case .string:
            return .string(unescape(token.text))
        case .symbol:
            switch token.text {
            case "true": return .bool(true)
            case "false": return .bool(false)
            case "nil": return .nil
            default: return .symbol(String(token.text))
            }
        }
    }
    
    mutating func parseList() throws (ParserError) -> EDNValue {
        var values: [EDNValue] = []
        while let token = lexer.next() {
            switch token.type {
            case .leftParen:  values.append(try parseList())
            case .leftBracket: values.append(try parseVector())
            case .rightParen: return EDNValue.list(values)
            case .comma:      continue
            default:          values.append(try parseValue(token))
            }
        }
        throw ParserError(.unexpectedEndOfList, lexer.location)
    }

    mutating func parseVector() throws (ParserError) -> EDNValue {
        var values: [EDNValue] = []
        while let token = lexer.next() {
            switch token.type {
            case .leftParen:  values.append(try parseList())
            case .leftBracket: values.append(try parseVector())
            case .rightBracket: return EDNValue.vector(values)
            case .comma:      continue
            default:          values.append(try parseValue(token))
            }
        }
        throw ParserError(.unexpectedEndOfList, lexer.location)
    }
}
