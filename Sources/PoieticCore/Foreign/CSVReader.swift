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
/// An exception to the specification: Characters after a final field quote are added to the field
/// until a field or a record separator is encountered. Double quotes are converted to single
/// quotes. This is a behaviour that has been observed by MS Excel and Apple Numbers.
///
public class CSVReader: Sequence, IteratorProtocol {
    enum State {
        case recordStart
        case fieldStart
        case inField
        case inQuote
        case pastQuote
    }
    
    public private(set) var options: CSVOptions
    public private(set) var string: String
    var currentIndex: String.Index
    var endIndex: String.Index
    var state: State

    /// Create a new CSV reader from a string.
    ///
    /// - Parameters:
    ///     - string: Source string containing a comma-separated data.
    ///     - options: Options for parsing the string.
    ///
    /// - SeeAlso: ``next()``
    ///
    public init(_ string: String = "", options: CSVOptions=CSVOptions()) {
        self.string = string
        self.currentIndex = string.startIndex
        self.endIndex = string.endIndex
        self.options = options
        self.state = .recordStart
    }
    
    func peek(offset: Int = 0) -> Character? {
        assert(currentIndex <= endIndex)
        let peekIndex = string.index(currentIndex, offsetBy: offset)
        guard peekIndex < endIndex else {
            return nil
        }
        return string[currentIndex]
    }
    
    /// Flag whether the reader is at the end of the source string.
    ///
    public var atEnd: Bool { currentIndex >= endIndex }
    
    /// Advance the reader and optionally append the current chacter into the
    /// token text.
    ///
    func advance() {
        currentIndex = string.index(after: currentIndex)
    }
    
    /// Get a next row in the CSV source.
    ///
    /// A row is an array of fields as strings.
    ///
    /// If the reader is at the end then `nil` is returned. This is notable when the last record
    /// is terminated with a record separator (typically a newline). The next row is `nil`, not an
    /// empty row.
    ///
    public func next() -> [String]? {
        var row: [String] = []
        var field = ""
        
        guard !atEnd else {
            return nil
        }
        
        loop:
        while !atEnd {
            guard let current = peek() else {
                break
            }

            switch (state, current) {
            case (.recordStart, options.fieldDelimiter),
                 (.fieldStart, options.fieldDelimiter),
                 (.inField, options.fieldDelimiter),
                 (.pastQuote, options.fieldDelimiter): // not .inQuote
                advance()
                row.append(field)
                field = ""
                state = .fieldStart
                
            case (.recordStart, options.recordDelimiter),
                 (.fieldStart, options.recordDelimiter),
                 (.inField, options.recordDelimiter),
                 (.pastQuote, options.recordDelimiter): // not .inQuote
                row.append(field)
                field = ""
                advance()
                state = .recordStart
                break loop
                
            case (.recordStart, options.quoteCharacter),
                 (.fieldStart, options.quoteCharacter):
                advance()
                state = .inQuote

            case (.inQuote, options.quoteCharacter):
                advance()
                if peek() == options.quoteCharacter {
                    field.append(options.quoteCharacter)
                    advance()
                }
                else {
                    state = .pastQuote
                }

            case (.pastQuote, options.quoteCharacter),
                 (.inField, options.quoteCharacter):
                field.append(options.quoteCharacter)
                advance()
                if peek() == options.quoteCharacter {
                    advance()
                }
                
            case (.recordStart, _),
                 (.fieldStart, _),
                 (.inField, _):
                state = .inField
                field.append(current)
                advance()
                
            case (.inQuote, _),
                 (.pastQuote, _):
                advance()
                field.append(current)
            }
        }
        
        if state != .recordStart {
            row.append(field)
            field = ""
            state = .recordStart
        }

        return row
    }
}
