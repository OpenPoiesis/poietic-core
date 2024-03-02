//
//  CSVReader.swift
//
//  Created by Stefan Urbanek on 2021/8/31.
//


/// Simple CSV string reader.
///
/// CSVReader reads a string containing a comma separated values and then
/// generates list of rows where a row is a list of values. All values are
/// string values.
///
/// CSV reading is according to [RFC4180](https://datatracker.ietf.org/doc/html/rfc4180).
///
class CSVReader: Sequence, IteratorProtocol {
    public enum Token: Equatable {
        case empty
        case value(String)
        case recordSeparator
        case fieldSeparator
    }
    
    var options: CSVOptions
    
    var iterator: String.Iterator
    var currentChar: Character?
    public var tokenText: String = ""
    
    init(_ iterator: String.Iterator, options: CSVOptions=CSVOptions()) {
        self.iterator = iterator
        currentChar = self.iterator.next()
        self.options = options
    }
    
    init(_ string: String = "", options: CSVOptions=CSVOptions()) {
        iterator = string.makeIterator()
        currentChar = iterator.next()
        self.options = options
    }
    
    var atEnd: Bool { currentChar == nil }
    
    /// Advance the reader and optionally append the current chacter into the
    /// token text.
    ///
    func advance(append: Bool=true) {
        if let char = currentChar, append {
            tokenText.append(char)
        }
        currentChar = iterator.next()
    }
    
    /// Get a next CSV token.
    ///
    func nextToken() -> Token {
        tokenText = ""

        if atEnd {
            return .empty
        }
        else if currentChar == options.recordDelimiter {
            advance()
            return .recordSeparator
        }
        else if currentChar == options.fieldDelimiter {
            advance()
            return .fieldSeparator
        }
        else if currentChar == "\"" {
            advance(append:false)
            var gotQuote: Bool = false
            
            while !atEnd {
                if currentChar == "\"" {
                    if gotQuote {
                        advance()
                        gotQuote = false
                    }
                    else {
                        // Maybe end, maybe escape, we don't append
                        advance(append:false)
                        gotQuote = true
                    }
                }
                else { // any character except quote
                    if gotQuote {
                        if currentChar == options.fieldDelimiter {
                            // We got a field separator after a quote
                            break
                        }
                        else if currentChar == options.recordDelimiter {
                            // We got a record separator after a quote
                            break
                        }
                        else {
                            // We eat anything after the closing quote
                            // Note: This behaviour was observed with both
                            // MS Excel and with Apple Numbers.
                            gotQuote = false
                            advance()
                        }
                    }
                    else { // got no quote
                        advance()
                    }
                }
            }
            return .value(tokenText)
        }
        else {
            while !atEnd {
                if currentChar == options.fieldDelimiter {
                    break
                }
                else if currentChar == options.recordDelimiter {
                    break
                }
                advance()
            }
            return .value(tokenText)
        }
    }
    
    /// Get the next row in the CSV source. A row is a list of string values.
    /// If the reader is at the end then `nil` is returned.
    ///
    func next() -> [String]? {
        guard !atEnd else {
            return nil
        }
        
        var row: [String] = []
        var hadValue = false
        
        loop: while !atEnd {
            // Whether the last token wa a value
            switch nextToken() {
            case .empty:
                break loop
            case .value(let text):
                row.append(text)
                hadValue = true
            case .fieldSeparator:
                if !hadValue {
                    // we did not have a value, we append an empty string
                    row.append("")
                }
                hadValue = false
            case .recordSeparator:
                if !hadValue {
                    row.append("")
                }
                break loop
            }
        }
        return row
    }
}

public enum CSVError: Error, CustomStringConvertible {
    case headerExpected
    
    public var description: String {
        switch self {
        case .headerExpected: "Expected a header with field names."
        }
    }
}

/// Reads a CSV text and yields one `ForeignRecord` per CSV record.
///
/// The `ForeignRecord` values are all strings.
///
public class CSVForeignRecordReader: Sequence, IteratorProtocol {
    let _reader: CSVReader
    let fields: [String]
    
    public init(_ string: String = "",
                fields: [String]? = nil,
                options: CSVOptions=CSVOptions()) throws {
        _reader = CSVReader(string, options: options)
        if let fields {
            self.fields = fields
        }
        else {
            guard let header = _reader.next() else {
                throw CSVError.headerExpected
            }
            self.fields = header
        }
    }
    
    /// Get a next record from the CSV and return it as a `ForeignRecord`.
    ///
    /// If end-of-the CSV data is reached, `nil` is returned.
    ///
    /// The `ForeignRecord` values are all strings, no conversion is performed.
    ///
    public func next() -> ForeignRecord? {
        guard let values = _reader.next() else {
            return nil
        }
        
        var dict: [String:Variant] = [:]
        
        for (key, value) in zip(fields, values) {
            dict[key] = Variant(value)
        }
        return ForeignRecord(dict)
    }
}
