//
//  Lexer.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2022.
//

/// Human-oriented location within a text.
///
/// `TextLocation` refers to a line number and a column within that line.
///
public struct TextLocation: CustomStringConvertible, Equatable, Sendable {
    // NOTE: This has been separated from Lexer when I had some ideas about
    // sharing code for two language parsers. Not sure if it makes sense now
    // and whether it should not be brought back to Lexer. Keeping it here for
    // now.
    
    /// Line number in human representation, starting with 1.
    public var line: Int = 1
    
    /// Column number in human representation, starting with 1 for the
    /// leftmost column.
    public var column: Int = 1

    public var index: String.Index
    
    public init(line: Int, column: Int, index: String.Index) {
        self.line = line
        self.column = column
        self.index = index
    }
    
    public init(string: String, index: String.Index) {
        var current = string.startIndex
        
        var column: Int = 0
        var line: Int = 1
        
        while current < index {
            let char = string[current]
            if char.isNewline {
                column = 0
                line += 1
            }
            else {
                column += 1
            }
            current = string.index(after: current)
        }
        
        self.line = line
        self.column = column
        self.index = index
    }
    
    public var description: String {
        return "\(line):\(column)"
    }
}

/// Token of an arithmetic expression.
///
public struct ExpressionToken {
    public enum TokenType: Equatable, Sendable {
        case identifier
        case int
        case float
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
    public var text: String { String(source[range]) }

    /// Human-oriented location of the token within the source string.
    public var textLocation: TextLocation {
        TextLocation(string: source, index: range.lowerBound)
    }
    
    public init(type: TokenType,
                source: String,
                range: Range<String.Index>) {
        self.type = type
        self.range = range
        self.source = source
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
    @usableFromInline
    var currentIndex: String.Index
    @usableFromInline
    var endIndex: String.Index

    /// Flag whether the reader is at the end of the source string.
    ///
    public var atEnd: Bool { currentIndex >= endIndex }

    public init(string: String) {
        self.source = string
        self.currentIndex = source.startIndex
        self.endIndex = source.endIndex
    }
    @inlinable
    func peek(offset: Int = 0) -> Character? {
        guard !atEnd else {
            return nil
        }
        guard let peekIndex = source.index(currentIndex, offsetBy: offset, limitedBy: endIndex) else {
            return nil
        }
        return source[peekIndex]
    }
    
    @inlinable
    mutating func advance() {
        currentIndex = source.index(after: currentIndex)
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
                case "+", "*", "/", "%", "^": type = .operator
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
                switch char {
                case "_":
                    advance()
                case _ where char.isWholeNumber:
                    advance()
                case ".":
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
                case "e", "E":
                    advance()
                    if peek() == "-" || peek() == "+" {
                        advance()
                    }
                    state = .exponent
                case _ where char.isLetter:
                    advance()
                    type = .error(.invalidCharacterInNumber)
                default:
                    type = .int
                }
            case .decimal:
                switch char {
                case "_":
                    advance()
                case _ where char.isWholeNumber:
                    advance()
                case "e", "E":
                    advance()
                    if peek() == "-" || peek() == "+" {
                        advance()
                    }
                    state = .exponent
                case _ where char.isLetter:
                    advance()
                    type = .error(.invalidCharacterInNumber)
                default:
                    type = .float
                }
            case .exponent:
                switch char {
                case "_":
                    advance()
                case _ where char.isWholeNumber:
                    advance()
                case _ where char.isLetter:
                    advance()
                    type = .error(.invalidCharacterInNumber)
                default:
                    type = .float
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
            case .decimal, .exponent: return .float
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

        while let char = peek(), char.isWhitespace || char.isNewline {
            advance()
        }
 
        let startIndex = currentIndex
        let token = nextToken()
        
        guard token != .empty else {
            return ExpressionToken(type: .empty,
                                   source: source,
                                   range: (startIndex..<currentIndex))
        }

        let endIndex = currentIndex

        return ExpressionToken(type: token,
                               source: source,
                               range: (startIndex..<endIndex))

    }
}
