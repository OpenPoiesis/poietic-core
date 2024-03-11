//
//  Token.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2022.
//

/// Token represents a lexical unit of the source.
///
/// The token includes trivia - leading and trailing whitespace. This
/// information is preserved for potential programmatic source code editing
/// while preserving the user formatting.
///
public struct Token<T: Equatable>: Equatable {
    public typealias TokenType = T
    /// Type of the token as resolved by the lexer
    public let type: T

    /// Range of the token within the source string
    public let range: Range<String.Index>
    
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
}

