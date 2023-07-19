//
//  Lexer.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2022.
//


/// An object for lexical analysis of an arithmetic expression.
///
/// Lexer takes a string containing an arithmetic expression and returns a list
/// of tokens.
///
/// - SeeAlso:
///     - ``ExpressionToken``
///
public class ExpressionLexer {
    public let scanner: Scanner
    
    public init(scanner: Scanner) {
        self.scanner = scanner
    }
    
    /// Creates a lexer that parses a source string.
    ///
    public convenience init(string: String) {
        self.init(scanner: Scanner(string: string))
    }

    public func advance() {
        scanner.advance()
    }

    public func accept() {
        scanner.accept()
    }
    
    @discardableResult
    public func accept(_ character: Character) -> Bool {
        return scanner.accept(character)
    }
    
    @discardableResult
    public func accept(_ predicate: (Character) -> Bool) -> Bool {
        return scanner.accept(predicate)
    }
    public var atEnd: Bool {
        return scanner.atEnd
    }
    
    /// Accepts an integer or a floating point number.
    ///
    func acceptNumber() -> TokenType? {
        var type: TokenType = .int
        
        if !accept(\.isWholeNumber) {
            return nil
        }

        while accept(\.isWholeNumber) || accept("_") {
            // Just accept it
        }

        if accept(".") {
            // At least one number after the decimal point
            if !accept(\.isWholeNumber) {
                return .error(.invalidCharacterInNumber)
            }
            while accept(\.isWholeNumber) || accept("_") {
                // Just accept it
            }

            type = .double
        }
        
        if accept("e") || accept("E") {
            // Possible float
            // At least one number after the decimal point
            accept("-")
            if !accept(\.isWholeNumber) {
                return .error(.invalidCharacterInNumber)
            }
            while accept(\.isWholeNumber) || accept("_") {
                // Just accept it
            }
            type = .double
        }
        
        if accept(\.isLetter) {
            return .error(.invalidCharacterInNumber)
        }
        else {
            return type
        }
    }
    
    /// Accepts an identifier.
    ///
    /// Identifier is a sequence of characters that start with a letter or an
    /// underscore `_`.
    ///
    func acceptIdentifier() -> TokenType? {
        // TODO: Allow quoting of the identifier
        guard accept(\.isLetter) || accept("_") else {
            return nil
        }

        while accept(\.isLetter) || accept(\.isWholeNumber) || accept("_") {
            // Just accept it
        }
        
        return .identifier
    }

    func acceptOperator() -> TokenType? {
        if accept("-") || accept("+") || accept("*") || accept("/") || accept("%") {
            return .operator
        }
        else {
            return nil
        }
    }

    func acceptPunctuation() -> TokenType? {
        if accept("(") {
            return .leftParen
        }
        else if accept(")") {
            return .rightParen
        }
        else if accept(",") {
            return .comma
        }
        else {
            return nil
        }
    }
    
    /// Accept a valid token.
    public func acceptToken() -> TokenType? {
        return acceptNumber()
                ?? acceptIdentifier()
                ?? acceptOperator()
                ?? acceptPunctuation()
    }
    
    /// Accepts leading trivia.
    ///
    /// When parsing for an expression then the trivia contains only whitespace.
    /// When parsing for a model, then the trivia contains also comments.
    public func acceptLeadingTrivia() {
        while accept(\.isWhitespace) {
            // Just skip
        }
    }
    
    public func acceptTrailingTrivia() {
        while(!accept(\.isNewline) && accept(\.isWhitespace)) {
            // Just skip
        }
    }


    /// Parse and return next token.
    ///
    /// Returns a token of type ``TokenType/empty`` when the end of the
    /// string has been reached.
    ///
    public func next() -> Token {
        // Trivia:
        //
        // Inspiration from Swift: swift/include/swift/Syntax/Trivia.h.gyb
        // At this moment there is no reason for parsing the trivia one way
        // or the other.
        //
        // 1. A token owns all of its trailing trivia up to, but not including,
        //    the next newline character.
        //
        // 2. Looking backward in the text, a token owns all of the leading trivia
        //    up to and including the first contiguous sequence of newlines characters.

        // Leading trivia
        let leadingTriviaStartIndex = scanner.currentIndex
        acceptLeadingTrivia()
        let leadingTriviaRange = leadingTriviaStartIndex..<scanner.currentIndex
        
        // Token text start index
        let startIndex = scanner.currentIndex

        if atEnd {
            return Token(type: .empty,
                         source: scanner.source,
                         range: (startIndex..<scanner.currentIndex),
                         leadingTriviaRange: leadingTriviaRange,
                         textLocation: scanner.location)
        }
        else if let type = acceptToken() {

            // Parse trailing trivia
            //
            let endIndex = scanner.currentIndex
            let trailingTriviaStartIndex = scanner.currentIndex
            acceptTrailingTrivia()
            let trailingTriviaRange = trailingTriviaStartIndex..<scanner.currentIndex


            return Token(type: type,
                         source: scanner.source,
                         range: (startIndex..<endIndex),
                         leadingTriviaRange: leadingTriviaRange,
                         trailingTriviaRange: trailingTriviaRange,
                         textLocation: scanner.location)
        }
        else {
            accept()
            return Token(type: .error(.unexpectedCharacter),
                         source: scanner.source,
                         range: (startIndex..<scanner.currentIndex),
                         leadingTriviaRange: leadingTriviaRange,
                         textLocation: scanner.location)
        }
    }

}
