//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

/// Set of options to read CSV files.
///
public class CSVOptions {
    
    /// Field delimiter character. Default is a comma `,`.
    ///
    public let fieldDelimiter: Character
    /// Record delimiter character. Default is a new line character `\n`.
    ///
    public let recordDelimiter: Character
    
    public let quoteCharacter: Character

    public init(fieldDelimiter: Character=",",
                recordDelimiter: Character="\n",
                quoteCharacter: Character="\"") {
        self.fieldDelimiter = fieldDelimiter
        self.recordDelimiter = recordDelimiter
        self.quoteCharacter = quoteCharacter
    }
}

