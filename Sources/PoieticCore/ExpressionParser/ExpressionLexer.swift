//
//  Lexer.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2022.
//

/// Token of an arithmetic expression.
///
/// ## Trivia
///
/// Inspiration from Swift: swift/include/swift/Syntax/Trivia.h.gyb
/// At this moment there is no reason for parsing the trivia one way
/// or the other.
///
/// 1. A token owns all of its trailing trivia up to, but not including,
///    the next newline character.
///
/// 2. Looking backward in the text, a token owns all of the leading trivia
///    up to and including the first contiguous sequence of newlines characters.
public struct ExpressionToken {
    public enum TokenType: Equatable, Sendable {
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
    }


    public let source: String
    
    /// Type of the token as resolved by the lexer
    public let type: TokenType

    /// Range of the token within the source string
    public let range: Range<String.Index>
    
    /// The token text.
    public var text: Substring { source[range] }

        /// Range of the trivia that precede the token.
    public let leadingTriviaRange: Range<String.Index>
    public var leadingTrivia: Substring { source[leadingTriviaRange] }
    
    /// Range of the trivia that follow the token.
    public let trailingTriviaRange: Range<String.Index>
    public var trailingTrivia: Substring { source[trailingTriviaRange] }

    /// Human-oriented location of the token within the source string.
    public var textLocation: TextLocation {
        TextLocation(string: source, index: range.lowerBound)
    }
    
    public init(type: TokenType,
                source: String,
                range: Range<String.Index>,
                leadingTriviaRange: Range<String.Index>? = nil,
                trailingTriviaRange: Range<String.Index>? = nil) {
        self.type = type
        self.range = range
        self.source = source

        self.leadingTriviaRange = leadingTriviaRange ?? (range.lowerBound..<range.lowerBound)
        self.trailingTriviaRange = trailingTriviaRange ?? (range.upperBound..<range.upperBound)
    }
    
    /// Full text of the token - including leading and trailing trivia.
    ///
    /// If ``fullText`` from all tokens is joined it must provide the original
    /// source string.
    ///
    public var fullText: String {
        String(leadingTrivia) + String(text) + String(trailingTrivia)
    }

}

/// An object for lexical analysis of an arithmetic expression.
///
/// Lexer takes a string containing an arithmetic expression and returns a list
/// of tokens.
///
/// - SeeAlso:
///     - ``ExpressionToken``
///
public struct ExpressionLexer {
    public let source: String
    var currentIndex: String.Index
    var endIndex: String.Index

    /// Flag whether the reader is at the end of the source string.
    ///
    public var atEnd: Bool { currentIndex >= endIndex }

    public init(string: String) {
        self.source = string
        self.currentIndex = source.startIndex
        self.endIndex = source.endIndex
    }
    
    func peek(offset: Int = 0) -> Character? {
        guard !atEnd else {
            return nil
        }
        guard let peekIndex = source.index(currentIndex, offsetBy: offset, limitedBy: endIndex) else {
            return nil
        }
        return source[peekIndex]
    }
    
    mutating func advance() {
        currentIndex = source.index(after: currentIndex)
    }

    /// Accepts leading trivia.
    ///
    /// When parsing for an expression then the trivia contains only whitespace.
    /// When parsing for a model, then the trivia contains also comments.
    ///
    public mutating func acceptLeadingTrivia() {
        while let char = peek() {
            if char.isWhitespace || char.isNewline {
                advance()
            }
            else if char == "#" {
                advance()
                while let char = peek(), !char.isNewline {
                    advance()
                }
            }
            else {
                break
            }
        }
    }
    
    public mutating func acceptTrailingTrivia() {
        while let current = peek(), current.isWhitespace {
            advance()
        }
        
        if peek() == "#" {
            advance()
            while let char = peek(), !char.isNewline {
                advance()
            }
        }
    }

    enum State: String {
        case begin
        case int
        case decimal
        case exponent
        case identifier
    }
   
    mutating func nextToken() -> ExpressionToken.TokenType {
        var type: ExpressionToken.TokenType? = nil
        var state: State = .begin
        
        if atEnd {
            return .empty
        }
        
        while let char = peek(), type == nil {
            switch state {
            case .begin:
                advance()
                
                switch char {
                case "(": type = .leftParen
                case ")": type = .rightParen
                case ",": type = .comma
                case "-":
                    if let nextChar = peek(), nextChar.isWholeNumber {
                        advance()
                        state = .int
                    }
                    else {
                        type = .operator
                    }
                case "_": state = .identifier
                case "+", "*", "/", "%": type = .operator
                case "<", ">", "!":
                    if peek() == "=" {
                        advance()
                    }
                    type = .operator
                case "=":
                    if peek() == "=" {
                        advance()
                        type = .operator
                    }
                    else {
                        type = .error(.unexpectedCharacter)
                    }
                default:
                    if char.isWholeNumber {
                        state = .int
                    }
                    else if char.isLetter {
                        state = .identifier
                    }
                    else {
                        type = .error(.unexpectedCharacter)
                    }
                }
            case .int:
                if char.isWholeNumber || char == "_" {
                    advance()
                }
                else if char == "." {
                    advance()
                    if let nextChar = peek() {
                        advance()
                        if nextChar.isWholeNumber {
                            state = .decimal
                        }
                        else {
                            type = .error(.invalidCharacterInNumber)
                        }
                    }
                    else {
                        type = .error(.numberExpected)
                    }
                }
                else if char == "e" || char == "E" {
                    advance()
                    if peek() == "-" || peek() == "+" {
                        advance()
                    }
                    state = .exponent
                }
                else if char.isLetter {
                    advance()
                    type = .error(.invalidCharacterInNumber)
                }
                else {
                    type = .int
                }
            case .decimal:
                if char.isWholeNumber || char == "_" {
                    advance()
                }
                else if char == "e" || char == "E" {
                    advance()
                    if peek() == "-" || peek() == "+" {
                        advance()
                    }
                    state = .exponent
                }
                else if char.isLetter {
                    advance()
                    type = .error(.invalidCharacterInNumber)
                }
                else {
                    type = .double
                }
            case .exponent:
                if char.isWholeNumber || char == "_" {
                    advance()
                }
                else if char.isLetter {
                    advance()
                    type = .error(.invalidCharacterInNumber)
                }
                else {
                    type = .double
                }
            case .identifier:
                if char.isLetter || char.isWholeNumber || char == "_" {
                    advance()
                }
                else {
                    type = .identifier
                }
            }
        }
        if let type {
            return type
        }
        else {
            switch state {
            case .int: return .int
            case .decimal, .exponent: return .double
            case .identifier: return .identifier
            default:
                return .error(.unexpectedCharacter)
            }
        }
    }
    var location: TextLocation {
        TextLocation(string: source, index: currentIndex)
    }

    mutating func next() -> ExpressionToken {
        guard !atEnd else {
            return ExpressionToken(type: .empty,
                                   source: source,
                                   range: (endIndex..<endIndex))
        }

        let leadingTriviaStartIndex = currentIndex
        acceptLeadingTrivia()
        let leadingTriviaRange = leadingTriviaStartIndex..<currentIndex
        let startIndex = currentIndex

        let token = nextToken()
        
        guard token != .empty else {
            return ExpressionToken(type: .empty,
                                   source: source,
                                   range: (startIndex..<currentIndex),
                                   leadingTriviaRange: leadingTriviaRange,
                                   trailingTriviaRange: nil)
        }

        // Parse trailing trivia
        //
        let endIndex = currentIndex
        let trailingTriviaStartIndex = currentIndex
        acceptTrailingTrivia()
        let trailingTriviaRange = trailingTriviaStartIndex..<currentIndex


        return ExpressionToken(type: token,
                               source: source,
                               range: (startIndex..<endIndex),
                               leadingTriviaRange: leadingTriviaRange,
                               trailingTriviaRange: trailingTriviaRange)

    }
}
