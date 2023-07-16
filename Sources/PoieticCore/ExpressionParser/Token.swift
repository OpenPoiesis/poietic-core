//
//  Token.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2022.
//

public enum TokenType: Equatable {
    public typealias TokenError = SyntaxError
    
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
    case error(SyntaxError)
}

/// Token represents a lexical unit of the source.
///
/// The token includes trivia - leading and trailing whitespace. This
/// information is preserved for potential programmatic source code editing
/// while preserving the user formatting.
///
public struct Token: Equatable {
    /// Type of the token as resolved by the lexer
    public let type: TokenType

    /// Range of the token within the source string
    public let range: Range<String.Index>
    
    // FIXME: Bind the token to the text.
    /// The token text.
    public let text: String

    /// Range of the trivia that precede the token.
    public let leadingTriviaRange: Range<String.Index>
    public let leadingTrivia: String
    
    /// Range of the trivia that follow the token.
    public let trailingTriviaRange: Range<String.Index>
    public let trailingTrivia: String

    /// Human-oriented location of the token within the source string.
    public let textLocation: TextLocation

    
    public init(type: TokenType, source: String, range: Range<String.Index>,
         leadingTriviaRange: Range<String.Index>? = nil,
         trailingTriviaRange: Range<String.Index>? = nil,
         textLocation: TextLocation) {
        // FIXME: Use Substrings
        self.type = type
        self.range = range
        self.text = String(source[range])

        self.leadingTriviaRange = leadingTriviaRange ?? (range.lowerBound..<range.lowerBound)
        self.leadingTrivia = String(source[self.leadingTriviaRange])
        self.trailingTriviaRange = trailingTriviaRange ?? (range.upperBound..<range.upperBound)
        self.trailingTrivia = String(source[self.trailingTriviaRange])

        self.textLocation = textLocation
    }
    
    /// Full text of the token - including leading and trailing trivia.
    ///
    /// If ``fullText`` from all tokens is joined it must provide the original
    /// source string.
    ///
    public var fullText: String {
        return leadingTrivia + text + trailingTrivia
    }

    /// Return integer value of the token if the token represents an integer.
    ///
    /// The numeric string might contain optional digit separator underscore
    /// `_`. For example: `'1_000'` for 1000 or `'1_00_00'` for 10000.
    ///
    /// - Returns: Integer value if the text is a valid number, otherwise ``nil``.
    ///
    func intValue() -> Int? {
        guard self.type == .int else {
            return nil
        }
        
        var sanitizedString = text
        sanitizedString.removeAll { $0 == "_" }
        
        return Int(sanitizedString)

    }

    /// Return double floating point value of the token if the token
    /// represents a floating point number.
    ///
    /// The numberic string might contain optional digit separator underscore
    /// `_`. For example: `'1_000.0'` for 1000 or `'1_00_00.1'` for 10000.1
    ///
    /// - Returns: Double value if the text is a valid number, otherwise ``nil``.
    ///
    func doubleValue() -> Double? {
        guard self.type == .double else {
            return nil
        }
        
        var sanitizedString = text
        sanitizedString.removeAll { $0 == "_" }
        
        return Double(sanitizedString)
    }
}

