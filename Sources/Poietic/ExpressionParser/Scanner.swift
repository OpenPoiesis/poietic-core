//
//  LexerBase.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2022.
//

/// Human-oriented location within a text.
///
/// `TextLocation` refers to a line number and a column within that line.
///
public struct TextLocation: CustomStringConvertible, Equatable {
    // NOTE: This has been separated from Lexer when I had some ideas about
    // sharing code for two language parsers. Not sure if it makes sense now
    // and whether it should not be brought back to Lexer. Keeping it here for
    // now.
    
    /// Line number in human representation, starting with 1.
    var line: Int = 1
    
    /// Column number in human representation, starting with 1 for the
    /// leftmost column.
    var column: Int = 1

    /// Advances the location by one character.
    ///
    /// - Parameters:
    ///     - newLine: if `true` then we are advancing to the new line and
    ///       resetting the column to 1.
    ///
    mutating func advance(_ character: Character) {
        if character.isNewline {
            column = 1
            line += 1
        }
        else {
            column += 1
        }
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
public class Scanner {
    /// String to be tokenised.
    public let source: String
    
    /// Index of the current character
    public private(set) var currentIndex: String.Index
    
    /// Current character
    public private(set) var currentChar: Character?
    
    /// Human understandable location.
    public private(set) var location: TextLocation
    
    /// Creates a lexer that parses a source string.
    ///
    public init(string: String) {
        self.source = string
        currentIndex = string.startIndex
        
        if string.startIndex < string.endIndex {
            currentChar = string[currentIndex]
        }
        else {
            currentChar = nil
        }
        
        location = TextLocation()
    }
    
    /// Flag indicating whether the lexer reached the end of the source string.
    ///
    var atEnd: Bool {
        return currentIndex == source.endIndex
    }
    
    
    // MARK: Acceptance and advancement
    /// Advances the lexer by one character.
    ///
    /// This method is called when a character is accepted. It advances
    /// the reading position of the source and updates the text location.
    ///
    func advance() {
        guard !atEnd else {
            return
        }
        
        // Advance current index and current character
        //
        currentIndex = source.index(after: currentIndex)
        
        if currentIndex < source.endIndex {
            currentChar = source[currentIndex]
            location.advance(currentChar!)
        }
        else {
            currentChar = nil
        }
    }

    /// Accept a character at current position.
    ///
    /// - Precondition: The scanner must not be at the end.
    ///
    func accept() {
        guard currentChar != nil else {
            fatalError("Accepting without current character")
        }
        advance()
    }
    
    /// Accept a concrete character. Returns ``true`` if the current character
    /// is equal to the requested character.
    ///
    @discardableResult
    func accept(_ character: Character) -> Bool {
        if currentChar == character {
            accept()
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
    func accept(_ predicate: (Character) -> Bool) -> Bool {
        guard let char = currentChar else {
            return false
        }
        if predicate(char) {
            accept()
            return true
        }
        else {
            return false
        }
    }
}
