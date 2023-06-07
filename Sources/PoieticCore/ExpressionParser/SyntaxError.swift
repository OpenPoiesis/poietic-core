//
//  SyntaxError.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2022.
//


/// Error thrown by the expression language parser.
///
public enum SyntaxError: Error, Equatable, CustomStringConvertible {
    case invalidCharacterInNumber
    case unexpectedCharacter
    case missingRightParenthesis
    case expressionExpected
    case unexpectedToken
    
    public var description: String {
        switch self {
        case .invalidCharacterInNumber: return "Invalid character in a number"
        case .unexpectedCharacter: return "Unexpected character"
        case .missingRightParenthesis: return "Right parenthesis ')' expected"
        case .expressionExpected: return "Expected expression"
        case .unexpectedToken: return "Unexpected token"
        }
    }
}
