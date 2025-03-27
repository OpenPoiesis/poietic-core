//
//  TextLocation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 02/02/2025.
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
