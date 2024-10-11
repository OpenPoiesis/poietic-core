//
//  LexerBase.swift
//  
//
//  Created by Stefan Urbanek on 08/08/2023.
//

/// Protocol for token types used by the ``Lexer``.
///
/// The `TokenTypeProtocol` is typically used by enums.
///
public protocol TokenTypeProtocol: Equatable {
    /// An empty token.
    static var empty: Self { get }
    static var unexpectedCharacterError: Self { get }
}


/// Protocol for syntax lexers.
///
/// - Note: This protocol was created with purpose to support multiple
///         micro-DSLs. During prototyping phase there were several DSLs
///         created and discarded. I am keeping it here for other experiments.
///
public protocol Lexer {
    associatedtype TokenType: TokenTypeProtocol
    var scanner: Scanner { get set }
    
    var atEnd: Bool { get }
    mutating func acceptToken() -> TokenType?
    mutating func next() -> Token<TokenType>
}

/// An object for lexical analysis.
///
/// - SeeAlso:
///     - ``ExpressionToken``
///
extension Lexer {
    public var atEnd: Bool {
        return scanner.atEnd
    }
    
    /// Accepts leading trivia.
    ///
    /// When parsing for an expression then the trivia contains only whitespace.
    /// When parsing for a model, then the trivia contains also comments.
    ///
    public mutating func acceptLeadingTrivia() {
        // TODO: Do not allow comments in expressions?
        while !atEnd {
            guard let char = scanner.currentChar else {
                break
            }
            if char.isWhitespace || char.isNewline {
                scanner.advance()
            }
            else if char == "#" {
                scanner.advance()
                while !scanner.atEnd && !scanner.scanNewline() {
                    scanner.advance()
                }
            }
            else {
                break
            }
        }
    }
    
    public mutating func acceptTrailingTrivia() {
        // TODO: Do not allow comments in expressions?
        scanner.skipWhitespace()
        
        if scanner.currentChar == "#" {
            scanner.advance()
            while true {
                if scanner.atEnd {
                    break
                }
                else if let char = scanner.currentChar,
                        char.isNewline {
                    break
                }
                else {
                    scanner.advance()
                }
            }
        }
    }


    /// Parse and return next token.
    ///
    /// Returns a token of type ``TokenTypeProtocol/empty`` when the end of the
    /// string has been reached.
    ///
    public mutating func next() -> Token<TokenType> {
        // Trivia:
        //
        // Inspiration from Swift: swift/include/swift/Syntax/Trivia.h.gyb
        // At this moment there is no reason for parsing the trivia one way
        // or the other.
        //
        // 1. A token owns all of its trailing trivia up to, but not including,
        //    the next newline character.
        //
        // 2. Looking backward in the text, a token owns all of the leading trivia
        //    up to and including the first contiguous sequence of newlines characters.

        // Leading trivia
        let leadingTriviaStartIndex = scanner.currentIndex
        acceptLeadingTrivia()
        let leadingTriviaRange = leadingTriviaStartIndex..<scanner.currentIndex
        
        // Token text start index
        let startIndex = scanner.currentIndex

        if atEnd {
            return Token<TokenType>(type: .empty,
                         source: scanner.source,
                         range: (startIndex..<scanner.currentIndex),
                         leadingTriviaRange: leadingTriviaRange,
                         textLocation: scanner.location)
        }
        else if let type = acceptToken() {

            // Parse trailing trivia
            //
            let endIndex = scanner.currentIndex
            let trailingTriviaStartIndex = scanner.currentIndex
            acceptTrailingTrivia()
            let trailingTriviaRange = trailingTriviaStartIndex..<scanner.currentIndex


            return Token<TokenType>(type: type,
                         source: scanner.source,
                         range: (startIndex..<endIndex),
                         leadingTriviaRange: leadingTriviaRange,
                         trailingTriviaRange: trailingTriviaRange,
                         textLocation: scanner.location)
        }
        else {
            return Token<TokenType>(type: .unexpectedCharacterError,
                         source: scanner.source,
                         range: (startIndex..<scanner.currentIndex),
                         leadingTriviaRange: leadingTriviaRange,
                         textLocation: scanner.location)
        }
    }

}
