//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import SystemPackage

/// Formats a list of string values into a string that represents a
/// CSV record.
///
/// - Note: This implementation is not optimised for performance.
///
/// CSV formatting is according to [RFC4180](https://datatracker.ietf.org/doc/html/rfc4180).
///
public class CSVFormatter {
    public let options: CSVOptions

    public init(options: CSVOptions = CSVOptions()) {
        self.options = options
    }
    
    /// Quote a string if necessary.
    ///
    /// The character is surrounded by quotes if one of the following is
    /// encountered:
    ///
    /// - String contains a quote character.
    /// - String contains a field delimiter or a record delimiter character
    ///   specified in the ``options`` (see also ``CSVOptions``).
    ///
    /// If a quote character is encountered, it is prepended by another quote
    /// character, resulting in double-quote.
    ///
    /// Examples:
    ///
    /// - `100` → `100`
    /// - `flow` → `flow`
    /// - `Well, ok` → `"Well, ok"`
    /// - `"surrounded"` → `""surrounded""`
    ///
    /// Empty string is returned as empty.
    ///
    public func quote(_ string: String) -> String {
        var result: String = ""
        var needsQuote: Bool = false
        for char in string {
            if char == "\"" {
                needsQuote = true
                result.append("\"\"")
            }
            else if char == options.fieldDelimiter
                        || char == options.recordDelimiter {
                result.append(char)
                needsQuote = true
            }
            else {
                result.append(char)
            }
        }
        if needsQuote {
            return "\"\(result)\""
        }
        else {
            return result
        }
    }
    
    /// Formats a row of values into a string that represents a CSV record.
    ///
    /// The returned string is terminated by the record separator specified
    /// int ``options``.
    ///
    public func format(row: [String]) -> String {
        return ""
    }
}

/// A sketch of a CSVWriter.
///
/// - Important: This class is just a sketch. The interface will very likely
///   be changed.
public class CSVWriter {
    let path: String
    let file: FileDescriptor
    let formatter: CSVFormatter
    
    public init(path: String) throws {
        self.path = path
        self.file = try FileDescriptor.open(path, .writeOnly,
                                           options: [.truncate, .create],
                                           permissions: .ownerReadWrite)
        self.formatter = CSVFormatter()
    }
    
    public func write(row: [String]) throws {
        let output = formatter.format(row: row)
        try file.writeAll(output.utf8)
    }
    public func close() throws {
        try file.close()
    }
}
