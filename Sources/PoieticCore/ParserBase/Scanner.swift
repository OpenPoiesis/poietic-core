//
//  LexerBase.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2022.
//

public enum ScannerError: Error {
    case unexpectedEnd
}

// FIXME: Combine this with Lexer (?)
/// Human-oriented location within a text.
///
/// `TextLocation` refers to a line number and a column within that line.
///
public struct TextLocation: CustomStringConvertible, Equatable {
    // TODO: Rename to "SourceLocation"
    // TODO: Add "index"
    // NOTE: This has been separated from Lexer when I had some ideas about
    // sharing code for two language parsers. Not sure if it makes sense now
    // and whether it should not be brought back to Lexer. Keeping it here for
    // now.
    
    /// Line number in human representation, starting with 1.
    var line: Int = 1
    
    /// Column number in human representation, starting with 1 for the
    /// leftmost column.
    var column: Int = 1

    var index: String.Index
    
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

/// Base object for simple lexers.
///
/// - SeeAlso:
///     - ``Token``
///
public struct Scanner {
    /// String to be tokenised.
    public let source: String
    
    /// Index of the current character
    public private(set) var currentIndex: String.Index
    public let endIndex: String.Index
    /// Creates a lexer that parses a source string.
    ///
    public init(string: String) {
        self.source = string
        self.currentIndex = string.startIndex
        self.endIndex = string.endIndex
    }
    
    /// Flag indicating whether the lexer reached the end of the source string.
    ///
    var atEnd: Bool {
        return currentIndex == source.endIndex
    }
    
    var currentChar: Character? {
        if currentIndex < source.endIndex {
            source[currentIndex]
        }
        else {
            nil
        }
    }
    
    var location: TextLocation {
        TextLocation(string: source, index: currentIndex)
    }

    /// Advnace the scanner by one character.
    mutating func advance() {
        source.formIndex(after: &currentIndex)
    }

    /// Accept a concrete character. Returns ``true`` if the current character
    /// is equal to the requested character.
    ///
    @discardableResult
    mutating func scan(_ character: Character) -> Bool {
        if currentChar == character {
            source.formIndex(after: &currentIndex)
            return true
        }
        else {
            return false
        }
    }
    
    /// Accept a character that matches given predicate. Returns ``true`` if
    /// the predicate function returns ``true`` for the current character.
    ///
    @discardableResult
    mutating func scan(_ predicate: (Character) -> Bool) -> Bool {
        guard let char = currentChar else {
            return false
        }
        if predicate(char) {
            source.formIndex(after: &currentIndex)
            return true
        }
        else {
            return false
        }
    }
   
    mutating func scanNewline() -> Bool {
        if let char = currentChar, char.isNewline {
            source.formIndex(after: &currentIndex)
            return true
        }
        else {
            return false
        }
    }
    
    mutating func skipWhitespace() {
        var index = currentIndex
        
        while index < endIndex {
            let char = source[index]
            guard char.isWhitespace  else {
                break
            }
            source.formIndex(after: &index)
        }
        currentIndex = index
    }

    mutating func skipWhitespaceAndNewline() {
        var index = currentIndex
        
        while index < endIndex {
            let char = source[index]
            guard char.isWhitespace || char.isNewline  else {
                break
            }
            source.formIndex(after: &index)
        }
        currentIndex = index
    }

    
    /// Accepts an identifier.
    ///
    /// Identifier is a sequence of characters that start with a letter or an
    /// underscore `_`.
    ///
    mutating func scanIdentifier() -> Bool {
        // TODO: Allow quoting of the identifier
        guard currentIndex < endIndex else {
            return false
        }
        var index = currentIndex
        let char = source[index]
        guard char.isLetter || char == "_" else {
            return false
        }
        source.formIndex(after: &index)

        while index < endIndex {
            let char = source[index]
            guard char.isLetter || char.isWholeNumber || char == "_"  else {
                break
            }
            source.formIndex(after: &index)
        }
        currentIndex = index
        return true
    }
    
    /// Accepts an integer.
    ///
    mutating func scanInt() -> Bool {
        var index = currentIndex
        
        guard index < endIndex else {
            return false
        }
        guard source[index].isWholeNumber else {
            return false
        }
        source.formIndex(after: &index)
        
        while index < endIndex {
            let char = source[index]
            guard char.isWholeNumber || char == "_" else {
                break
            }
            source.formIndex(after: &index)
        }
        currentIndex = index
        return true
    }
    
    /// Scan a string starting and ending with a quote `"`.
    ///
    /// The string might span multiple lines.
    ///
    /// - Throws: ``ScannerError.unexpectedEnd`` when an end is encountered
    ///  before the closing quote.
    ///
    mutating func scanQuotedString() throws -> Bool {
        var index = currentIndex
        
        guard index < endIndex else {
            return false
        }
        guard source[index] == "\"" else {
            return false
        }
        source.formIndex(after: &index)
        
        var escape: Bool = false
        var closed: Bool = false
        
        while index < endIndex {
            let char = source[index]
            if char == "\"" {
                if escape {
                    escape = false
                    source.formIndex(after: &index)
                }
                else {
                    closed = true
                    break
                }
            }
            else if char == "\\" {
                escape = !escape
            }
            else {
                escape = false
                source.formIndex(after: &index)
            }
        }
        
        guard closed else {
            throw ScannerError.unexpectedEnd
        }
            
        currentIndex = index

        return true
    }
}
