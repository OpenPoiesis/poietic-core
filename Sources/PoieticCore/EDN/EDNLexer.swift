//
//  EDNParser.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 12/03/2025.
//

enum EDNSyntaxError: Error, Equatable {
    case unexpectedCharacter
    case numberExpected
    case invalidCharacterInNumber
    case unexpectedEndOfString
    
    case unexpectedListEnd
    case unexpectedComma
    case invalidNumber
    case unexpectedEndOfList
}


/// Un-escape a string.
///
/// Convert escape sequences to their corresponding characters:
///
/// - `\0` - null character
/// - `\t` - tab (ASCII 7)
/// - `\n` - new line (ASCII 13)
/// - `\r` - carriage return (ASCII 10)
/// - `\"` - double quote
/// - `\'` - single quote
///
func unescape(_ text: Substring) -> String {
    var result: String = ""
    var index = text.startIndex
    
    while index < text.endIndex {
        let char = text[index]
        if char == "\\" {
            index = text.index(after: index)
            switch text[index] {
            case "0": result.append("\0")
            case "t": result.append("\t")
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "\"": result.append("\"")
            case "\'": result.append("\'")
            default: result.append(char)
            }
        }
        else {
            result.append(char)
        }
        
        index = text.index(after: index)
    }
    return result
}

/// Lexer for a subset of Extensible Data Notation.
///
/// From the [EDN Specification](https://github.com/edn-format/edn)
/// > edn is an extensible data notation. A superset of edn is used by Clojure to represent
/// > programs, and it is used by Datomic and other applications as a data transfer format.
///
/// EDN is used for persistence store.
///
/// We are using just a subset of EDN:
///
/// - only lists `(1 2 3)`, no vectors or maps
/// - no tagged elements (`#tag`)
/// - symbols can contain only the following special characters: `. _ - +`
///
/// SeeAlso: [EDN Specification](https://github.com/edn-format/edn)


struct EDNLexer {
    /// Source to be parsed.
    public let source: String
    /// Current parser position.
    var currentIndex: String.Index
    /// End of the source.
    var endIndex: String.Index

    /// Start of the next token
    var tokenStart: String.Index
    var tokenEnd: String.Index?

    var location: TextLocation {
        TextLocation(string: source, index: currentIndex)
    }

    /// Flag whether the reader is at the end of the source string.
    ///
    public var atEnd: Bool { currentIndex >= endIndex }

    enum TokenType: Equatable {
        case leftParen        // "("
        case rightParen       // ")"
        case comma            // ","
        case keyword          // e.g., ":edge"
        case string           // e.g., "thing"
        case int              // e.g., "10"
        case float            // e.g., "1.5"
        /// From the EDN spectification:
        ///
        /// > Symbols begin with a non-numeric character and can contain alphanumeric characters
        ///   and . * + ! - _ ? $ % & = < >.
        ///   If -, + or . are the first character, the second character (if any) must be
        ///   non-numeric.
        ///
        /// Our implementation: can start with any of `._` can contain `._-+`
        ///
        case symbol           // e.g., "parent-object-id"
        
        case error(EDNSyntaxError)
    }

    struct Token: Equatable {
        let type: TokenType
        let text: Substring
        init(_ type: TokenType, _ text: Substring) {
            self.type = type
            self.text = text
        }
    }
    
    enum State {
        case begin
        case int
        case decimal
        case exponent
        case string
        case symbol
        case keyword
    }
    
    public init(string: String) {
        self.source = string
        self.currentIndex = source.startIndex
        self.endIndex = source.endIndex
        
        self.tokenStart = currentIndex
        self.tokenEnd = nil
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

    mutating func lexToken() -> TokenType? {
        var tokenType: TokenType? = nil
        guard !atEnd else {
            return nil
        }

        var state: State = .begin

        while let char = peek(), tokenType == nil {
            switch state {
            case .begin:
                advance()
                
                switch char {
                case "(": tokenType = .leftParen
                case ")": tokenType = .rightParen
                case ",": tokenType = .comma
                case "\"":
                    tokenStart = currentIndex
                    state = .string
                case "-":
                    if let nextChar = peek(), nextChar.isWholeNumber {
                        advance()
                        state = .int
                    }
                    else {
                        tokenType = .error(.unexpectedCharacter)
                    }
                case _ where char.isWholeNumber: state = .int
                case ":": state = .keyword
                case "_", ".": state = .symbol
                case _ where char.isLetter: state = .symbol
                default:  tokenType = .error(.unexpectedCharacter)
                }
            case .string:
                switch char {
                case "\"":
                    tokenEnd = currentIndex
                    advance()
                    tokenType = .string
                case "\\": // Escape character
                    advance()
                    if atEnd {
                        tokenType = .error(.unexpectedEndOfString)
                    }
                    else {
                        // Eat escaped character
                        // TODO: Eat only known escape characters (\n \" \t, ...) or maybe just quote, not just any
                        // TODO: Remove escape characters
                        advance()
                    }
                default:
                    advance()
                }
            case .int:
                switch char {
                case _ where char.isWholeNumber: advance()
                case ".":
                    advance()
                    if let nextChar = peek() {
                        advance()
                        if nextChar.isWholeNumber {
                            state = .decimal
                        }
                        else {
                            tokenType = .error(.invalidCharacterInNumber)
                        }
                    }
                    else {
                        tokenType = .error(.numberExpected)
                    }
                case "e", "E":
                    advance()
                    if peek() == "-" || peek() == "+" {
                        advance()
                    }
                    state = .exponent
                case _ where char.isLetter:
                    advance()
                    tokenType = .error(.invalidCharacterInNumber)
                default: tokenType = .int
                }
            case .decimal:
                switch char {
                case _ where char.isWholeNumber: advance()
                case "e", "E":
                    advance()
                    if peek() == "-" || peek() == "+" {
                        advance()
                    }
                    state = .exponent
                case _ where char.isLetter:
                    advance()
                    tokenType = .error(.invalidCharacterInNumber)
                default: tokenType = .float
                }
            case .exponent:
                switch char {
                case _ where char.isWholeNumber: advance()
                case _ where char.isLetter:
                    advance()
                    tokenType = .error(.invalidCharacterInNumber)
                default: tokenType = .float
                }
            case .symbol:
                switch char {
                case "_", "+", "-", ".": advance()
                case _ where char.isLetter || char.isWholeNumber: advance()
                default: tokenType = .symbol
                }
            case .keyword:
                if char.isLetter || char.isWholeNumber || char == "_" {
                    advance()
                }
                else {
                    tokenType = .keyword
                }
            }
        }
        
        if let tokenType {
            return tokenType
        }
        else {
            switch state {
            case .int: return .int
            case .decimal, .exponent: return .float
            case .symbol: return .symbol
            case .keyword: return .keyword
            case .string: return .error(.unexpectedEndOfString)
            default: return .error(.unexpectedCharacter)
            }
        }
    }
    
    mutating func next() -> Token? {
        while let char = peek(), char.isWhitespace {
            // Eat whitespace
            advance()
        }
        tokenStart = currentIndex
        tokenEnd = nil
        
        if let type = lexToken() {
            let tokenEnd = tokenEnd ?? currentIndex
            let text = source[tokenStart..<tokenEnd]
            return Token(type, text)
        }
        else {
            return nil
        }
    }
}
