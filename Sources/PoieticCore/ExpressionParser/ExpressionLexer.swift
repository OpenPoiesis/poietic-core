//
//  Lexer.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2022.
//

public enum ExpressionTokenType: Equatable, TokenTypeProtocol, Sendable {
    public typealias TokenError = ExpressionSyntaxError
    
    // Expression tokens
    case identifier
    case int
    case double
    case `operator`
    case leftParen
    case rightParen
    case comma

    // Special tokens
    case empty
    case error(ExpressionSyntaxError)
    
    public static let unexpectedCharacterError = ExpressionTokenType.error(.unexpectedCharacter)
}

public typealias ExpressionToken = Token<ExpressionTokenType>

/// An object for lexical analysis of an arithmetic expression.
///
/// Lexer takes a string containing an arithmetic expression and returns a list
/// of tokens.
///
/// - SeeAlso:
///     - ``ExpressionToken``
///
public class ExpressionLexer: Lexer {
    public typealias TokenType = ExpressionTokenType
    public static let OperatorCharacters = "!%*+-/<=>"
    
    
    public var scanner: Scanner
    
    public init(scanner: Scanner) {
        self.scanner = scanner
    }
    
    /// Creates a lexer that parses a source string.
    ///
    public convenience init(string: String) {
        self.init(scanner: Scanner(string: string))
    }

    /// Accepts an integer or a floating point number.
    ///
    func acceptNumber() -> ExpressionTokenType? {
        var type: ExpressionTokenType = .int
        guard scanner.scanInt() else {
            return nil
        }
        
        if scanner.scan(".") {
            guard scanner.scanInt() else {
                // Include the erroneous character in the token text
                scanner.advance()
                return .error(.numberExpected)
            }
            type = .double
        }

        if scanner.scan("e") || scanner.scan("E") {
            scanner.scan("-")
            guard scanner.scanInt() else {
                // Include the erroneous character in the token text
                scanner.advance()
                return .error(.numberExpected)
            }
            type = .double
        }

        guard !(scanner.currentChar?.isLetter ?? false) else {
            // Include the erroneous character in the token text
            scanner.advance()
            return .error(.invalidCharacterInNumber)
        }

        return type
    }
    
    func acceptOperator() -> ExpressionTokenType? {
        if scanner.scan("-")
                || scanner.scan("+")
                || scanner.scan("*")
                || scanner.scan("/")
                || scanner.scan("%") {
            return .operator
        }
        else if scanner.scan("<") {  // < or <=
            scanner.scan("=")
            // TODO Make sure we do not have other operator characters here
            return .operator
        }
        else if scanner.scan(">") { // > or >=
            scanner.scan("=")
            // TODO Make sure we do not have other operator characters here
            return .operator
        }
        else if scanner.scan("=") {
            if scanner.scan("=") {  // binary ==
                return .operator
            }
            else {
                return .error(.unexpectedCharacter)
            }
        }
        else if scanner.scan("!") {   // unary !  or binary !=
            scanner.scan("=")
            // TODO Make sure we do not have other operator characters here
            return .operator
        }
        else {
            return nil
        }
    }

    /// Accepts an identifier.
    ///
    /// Identifier is a sequence of characters that start with a letter or an
    /// underscore `_`.
    ///
    func acceptIdentifier() -> ExpressionTokenType? {
        if scanner.scanIdentifier() {
            return .identifier
        }
        else {
            return nil
        }
    }
    
    func acceptPunctuation() -> ExpressionTokenType? {
        if scanner.scan("(") {
            return .leftParen
        }
        else if scanner.scan(")") {
            return .rightParen
        }
        else if scanner.scan(",") {
            return .comma
        }
        else {
            return nil
        }
    }
    
    /// Accept a valid token.
    public func acceptToken() -> ExpressionTokenType? {
        return acceptNumber()
                ?? acceptIdentifier()
                ?? acceptOperator()
                ?? acceptPunctuation()
    }
}
