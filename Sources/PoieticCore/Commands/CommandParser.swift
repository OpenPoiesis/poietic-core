//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/07/2023.
//

public enum CommandSyntaxError: Error, Equatable {
    case invalidCharacterInNumber
    case numberExpected
    case argumentValueExpected
    case unexpectedCharacter
    case semicolonExpected
    case unexpectedToken

    public var description: String {
        switch self {
        case .invalidCharacterInNumber: "Invalid character in a number"
        case .numberExpected: "Expected a number"
        case .argumentValueExpected: "Expected an argument value - a literal or an identifier"
        case .unexpectedCharacter: "Unexpected character"
        case .semicolonExpected: "Expected semicolon to separate commands"
        case .unexpectedToken: "Unexpected token"
        }
    }
}

public enum CommandTokenType: TokenTypeProtocol {
    public typealias TokenError = ExpressionSyntaxError
    
    // Expression tokens
    case identifier
    case keyword
    case int
    case double
    case string
    case arrayOpen
    case arrayClose
    case semicolon

    // Special tokens
    case empty
    case error(CommandSyntaxError)
    
    public static var unexpectedCharacterError = CommandTokenType.error(.unexpectedCharacter)
}

public typealias CommandToken = Token<CommandTokenType>

public protocol CommandSyntaxProtocol {
}

public protocol LiteralSyntaxProtocol {
    /// Converts the syntax node into a foreign value.
    ///
    /// All literal syntax nodes are convertible to a foreign value.
    ///
    func foreignValue() -> ForeignValue
}

public struct CommandSyntax: CommandSyntaxProtocol {
    public let name: CommandToken
    public let positionalArgs: [CommandArgumentSyntax]
    public let keywordArgs: [CommandKeywordSyntax]
}

public struct CommandKeywordSyntax {
    public let keyword: CommandToken
    public let value: CommandArgumentSyntax
}

public struct CommandArgumentSyntax {
    public let token: CommandToken
}

public struct CommandLexer: Lexer {
    public typealias TokenType = CommandTokenType
    public var scanner: Scanner
    
    public init(scanner: Scanner) {
        self.scanner = scanner
    }
    
    /// Creates a lexer that parses a source string.
    ///
    public init(string: String) {
        self.init(scanner: Scanner(string: string))
    }
    
    public func acceptBool() -> CommandToken? {
        return nil
    }
    /// Accepts an integer or a floating point number.
    ///
    mutating func acceptNumber() -> CommandTokenType? {
        guard scanner.scanInt() else {
            return nil
        }
        
        if scanner.scan(".") {
            guard scanner.scanInt() else {
                return .error(.numberExpected)
            }
            if scanner.scan("e") || scanner.scan("E") {
                scanner.scan("-")
                guard scanner.scanInt() else {
                    return .error(.numberExpected)
                }
            }
            guard !(scanner.currentChar?.isLetter ?? false) else {
                return .error(.invalidCharacterInNumber)
            }
            return .double
        }
        else {
            guard !(scanner.currentChar?.isLetter ?? false) else {
                return .error(.invalidCharacterInNumber)
            }
            return .int
        }
    }
    
    mutating func acceptString() -> CommandTokenType? {
        return nil
    }

    mutating func acceptArrayBoundary() -> CommandTokenType? {
        if scanner.scan("[") {
            return .arrayOpen
        }
        else if scanner.scan("]") {
            return .arrayClose
        }
        else {
            return nil
        }
    }
    
    mutating func acceptSemicolon() -> CommandTokenType? {
        if scanner.scan(";") {
            return .semicolon
        }
        else {
            return nil
        }
    }
    mutating public func acceptKeywordOrIdentifier() -> CommandTokenType? {
        guard scanner.scanIdentifier() else {
            return nil
        }

        if scanner.scan(":") {
            return .keyword
        }
        else {
            return .identifier
        }
    }
    
    public mutating func acceptToken() -> CommandTokenType? {
        return acceptNumber()
                ?? acceptKeywordOrIdentifier()
                ?? acceptString()
                ?? acceptArrayBoundary()
                ?? acceptSemicolon()
    }

}

class CommandParser {
    var lexer: CommandLexer
    var currentToken: CommandToken?
    
    /// Creates a new command parser using a command lexer.
    ///
    public init(lexer: CommandLexer) {
        self.lexer = lexer
        advance()
    }
    
    /// Creates a new parser for an expression source string.
    ///
    public convenience init(string: String) {
        self.init(lexer: CommandLexer(string: string))
    }
    
    /// True if the parser is at the end of the source.
    public var atEnd: Bool {
        if let token = currentToken {
            return token.type == .empty
        }
        else {
            return true
        }
    }

    /// Advance to the next token.
    ///
    func advance() {
        currentToken = lexer.next()
    }
    
    /// Accent a token a type ``type``.
    ///
    /// - Returns: A token if the token matches the expected type, ``nil`` if
    ///     the token does not match the expected type.
    ///
    func accept(_ type: CommandTokenType) -> CommandToken? {
        guard let token = currentToken else {
            return nil
        }
        if token.type == type {
            advance()
            return token
        }
        else {
            return nil
        }
    }
    
    func acceptBool() -> CommandToken? {
        guard let token = currentToken else {
            return nil
        }
        if token.type == .identifier
            && (token.text == "true" || token.text == "false") {
            advance()
            return token
        }
        else {
            return nil
        }
    }
    
    func acceptArray() -> CommandToken? {
        return nil
    }
    
    public func acceptLiteral() -> CommandToken? {
        return accept(.int)
                ?? accept(.double)
                ?? acceptBool()
                ?? accept(.string)
                ?? acceptArray()
    }

    public func acceptArgument() -> CommandArgumentSyntax? {
        guard let token = acceptLiteral() ?? accept(.identifier) else {
            return nil
        }
        return CommandArgumentSyntax(token: token)
    }
    
    public func acceptPositionalArguments() -> [CommandArgumentSyntax] {
        var args: [CommandArgumentSyntax] = []
        while let arg = acceptArgument() {
            args.append(arg)
        }
        return args
    }
    public func acceptKeywordArguments() throws -> [CommandKeywordSyntax] {
        var args: [CommandKeywordSyntax] = []
        while let keyword = accept(.keyword) {
            if let argument = acceptArgument() {
                let syntax = CommandKeywordSyntax(keyword: keyword,
                                                  value: argument)
                args.append(syntax)
            }
            else {
                throw CommandSyntaxError.argumentValueExpected
            }
        }
        return args
    }
    
    public func acceptCommand() throws -> CommandSyntax? {
        guard let name = accept(.identifier) else {
            return nil
        }
        
        let positional = acceptPositionalArguments()
        let keyword = try acceptKeywordArguments()

        return CommandSyntax(name: name,
                             positionalArgs: positional,
                             keywordArgs: keyword)
    }
    public func acceptCommands() throws -> [CommandSyntax]? {
        var commands: [CommandSyntax] = []
        
        while let command = try acceptCommand() {
            commands.append(command)
            if atEnd {
                break
            }
            if accept(.semicolon) == nil {
                throw CommandSyntaxError.semicolonExpected
            }
        }
        
        if atEnd {
            return commands
        }
        else {
            throw CommandSyntaxError.unexpectedToken
        }
    }
}
