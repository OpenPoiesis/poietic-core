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
            switch char {
            case options.quoteCharacter:
                needsQuote = true
                result.append(options.quoteCharacter)
                result.append(options.quoteCharacter)
            case options.fieldDelimiter,
                options.recordDelimiter:
                result.append(char)
                needsQuote = true
            default:
                result.append(char)
            }
        }
        if needsQuote {
            return String(options.quoteCharacter) + result + String(options.quoteCharacter)
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
    public func format(_ row: [String]) -> String {
        return row.map { quote($0) }
                .joined(separator: String(options.fieldDelimiter))
    }
}

/// A sketch of a CSVWriter.
///
/// - Important: This class is just a sketch. The interface will very likely
///   be changed.
public class CSVWriter {
    let file: FileDescriptor
    let formatter: CSVFormatter
    var fieldCount: Int?
    
    public convenience init(path: String, formatter: CSVFormatter = CSVFormatter()) throws {
        let file = try FileDescriptor.open(path, .writeOnly,
                                           options: [.truncate, .create],
                                           permissions: .ownerReadWrite)
        try self.init(file, formatter: formatter)
    }

    public init(_ descriptor: FileDescriptor, formatter: CSVFormatter = CSVFormatter()) throws {
        self.file = descriptor
        self.formatter = formatter
        self.fieldCount = nil
    }

    /// Writes a row to the output file.
    ///
    /// - Precondition: The number of items in the row must be exactly the same
    ///   as the number of rows in the very first row.
    public func write(row: [String]) throws {
        let output = formatter.format(row)
        if let fieldCount {
            precondition(row.count == fieldCount,
                         "The CSV record must have the same number of items as the very first record. It has \(row.count), expected \(fieldCount)")
            try file.writeAll(formatter.options.recordDelimiter.utf8)
        }
        else {
            self.fieldCount = row.count
        }
        try file.writeAll(output.utf8)
    }
    public func close() throws {
        try file.close()
    }
}
