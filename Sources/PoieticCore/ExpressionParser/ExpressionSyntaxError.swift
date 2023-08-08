//
//  SyntaxError.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2022.
//


/// Error thrown by the expression language parser.
///
public enum ExpressionSyntaxError: Error, Equatable, CustomStringConvertible {
    case invalidCharacterInNumber
    case numberExpected
    case unexpectedCharacter
    case missingRightParenthesis
    case expressionExpected
    case unexpectedToken
    
    public var description: String {
        switch self {
        case .invalidCharacterInNumber: "Invalid character in a number"
        case .numberExpected: "Expected a number"
        case .unexpectedCharacter: "Unexpected character"
        case .missingRightParenthesis: "Right parenthesis ')' expected"
        case .expressionExpected: "Expected expression"
        case .unexpectedToken: "Unexpected token"
        }
    }
}
