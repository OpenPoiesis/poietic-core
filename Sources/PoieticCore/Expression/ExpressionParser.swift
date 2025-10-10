//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 27/05/2022.
//

/// Error thrown by the expression language parser.
///
public enum ExpressionSyntaxError: Error, Equatable, CustomStringConvertible {
    case invalidCharacterInNumber
    case numberExpected
    case unexpectedCharacter
    case missingRightParenthesis
    case expressionExpected
    case unexpectedToken
    
    public var description: String {
        switch self {
        case .invalidCharacterInNumber: "Invalid character in a number"
        case .numberExpected: "Expected a number"
        case .unexpectedCharacter: "Unexpected character"
        case .missingRightParenthesis: "Right parenthesis ')' expected"
        case .expressionExpected: "Expected expression"
        case .unexpectedToken: "Unexpected token"
        }
    }
}

/// Abstract syntax tree of arithmetic expression.
///
public indirect enum ExpressionAST {
    case intLiteral(ExpressionToken)
    case doubleLiteral(ExpressionToken)
    case variable(ExpressionToken)
    case functionArgument(argument: ExpressionAST, comma: ExpressionToken?)
    case functionCall(name: ExpressionToken, arguments: [ExpressionAST], openParen: ExpressionToken, closeParen: ExpressionToken)
    case unaryOperator(operator: ExpressionToken, operand: ExpressionAST)
    case binaryOperator(operator: ExpressionToken, left: ExpressionAST, right: ExpressionAST)
    case parenthesis(expression: ExpressionAST, openParen: ExpressionToken, closeParen: ExpressionToken)

    /// Converts an expression syntax node into an unbound arithmetic
    /// expression.
    ///
    /// - SeeAlso: ``UnboundExpression``
    ///
    public func toExpression() -> UnboundExpression {
        switch self {
        case let .intLiteral(token):
            var sanitizedNumber = token.text
            sanitizedNumber.removeAll { $0 == "_" }
            guard let value = Int(sanitizedNumber) else {
                fatalError("Lexer error: invalid int token")
            }
            return .value(Variant(value))

        case let .doubleLiteral(token):
            var sanitizedNumber = token.text
            sanitizedNumber.removeAll { $0 == "_" }
            guard let value = Double(sanitizedNumber) else {
                fatalError("Lexer error: invalid double token")
            }
            return .value(Variant(value))

        case let .variable(token):
            return .variable(String(token.text))

        case let .unaryOperator(op, operand):
            return .unary(String(op.text), operand.toExpression())

        case let .binaryOperator(operator: op, left: left, right: right):
            return .binary(String(op.text), left.toExpression(), right.toExpression())

        case let .functionCall(name: name, arguments: args, _, _):
            let expressions = args.map {
                $0.toExpression()
            }
            return .function(String(name.text), expressions)

        case let .parenthesis(expression: expr, _, _):
            return expr.toExpression()

        case .functionArgument(argument: let argument, _):
            return argument.toExpression()
        }
    }
    
    public var fullText: String {
        switch self {
        case let .intLiteral(token):
            return token.text
        case let .doubleLiteral(token):
            return token.text
        case let .variable(token):
            return token.text
        case let .functionArgument(argument: argument, comma: comma):
            if let comma {
                return argument.fullText + comma.text
            }
            else {
                return argument.fullText
            }
        case let .functionCall(name: name, arguments: arguments, openParen: openParen, closeParen: closeParen):
            return name.text + openParen.text + arguments.map(\.fullText).joined() + closeParen.text
        case let .unaryOperator(operator: op, operand: operand):
            return op.text + operand.fullText
        case let .binaryOperator(operator: op, left: left, right: right):
            return left.fullText + op.text + right.fullText
        case let .parenthesis(expression: expression, openParen: openParen, closeParen: closeParen):
            return openParen.text + expression.fullText + closeParen.text
        }
    }

}

// https://craftinginterpreters.com/parsing-expressions.html
// https://stackoverflow.com/questions/2245962/writing-a-parser-like-flex-bison-that-is-usable-on-8-bit-embedded-systems/2336769#2336769


/// Parser for arithmetic expressions.
///
/// The parses takes a string as an input and creates an unbound arithmetic
/// expression.
///
/// The elements of an arithmetic expression can be:
///
/// - numeric literals: integers (for example `0`, `10`, `128`)
///   or floating point numbers (`1.5e10`)
/// - variable or function identifiers
/// - arithmetic operators `+`, `-`, `*`, `/`, `%` (as modulo)
/// - comparison operators `==`, `!=`, `<`, `>`, `<=`, `>=`
/// - parethesis `(`, `)` for grouping sub-expressions
/// - function calls (`min(a, b)`)
///
/// Parser produces ``UnboundExpression``.
///
public class ExpressionParser {
    var lexer: ExpressionLexer
    var currentToken: ExpressionToken?
    
    // TODO: Add: public static parsing(string:) throws -> UnboundExpression
    /// Creates a new parser using an expression lexer.
    ///
    public init(lexer: ExpressionLexer) {
        self.lexer = lexer
        advance()
    }
    
    /// Creates a new parser for an expression source string.
    ///
    public convenience init(string: String) {
        self.init(lexer: ExpressionLexer(string: string))
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
    func accept(_ type: ExpressionToken.TokenType) -> ExpressionToken? {
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

    // ----------------------------------------------------------------
    
    /// Parse an operator.
    func `operator`(_ op: String) -> ExpressionToken? {
        guard let token = currentToken else {
            return nil
        }
        if token.type == .operator && token.text == op {
            advance()
            return token
        }
        else {
            return nil
        }

    }
    
    /// Parse an identifier - a variable name or a function name.
    ///
    func identifier() -> ExpressionToken? {
        if let token = accept(.identifier) {
            return token
        }
        else {
            return nil
        }
    }

    /// Parse an integer or a float.
    ///
    func number() -> ExpressionAST? {
        if let token = accept(.int) {
            return .intLiteral(token)
        }
        else if let token = accept(.float) {
            return .doubleLiteral(token)
        }
        else {
            return nil
        }
    }
    
    /// Rule:
    ///
    ///     variable_call -> IDENTIFIER ["(" ARGUMENTS ")"]
    ///
    func variable_or_call() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard let ident = identifier() else {
            return nil
        }

        if let lparen = accept(.leftParen) {
            var arguments: [ExpressionAST] = []
            repeat {
                guard let expr = try expression() else {
                    break
                }
                
                if let comma = accept(.comma) {
                    let arg: ExpressionAST = .functionArgument(argument:expr, comma: comma)
                    arguments.append(arg)
                }
                else {
                    let arg: ExpressionAST = .functionArgument(argument:expr, comma: nil)
                    arguments.append(arg)
                    break
                }
            } while true

            guard let rparen = accept(.rightParen) else {
                throw .missingRightParenthesis
            }

            return .functionCall(name: ident,
                                 arguments: arguments,
                                 openParen: lparen,
                                 closeParen: rparen)
        }
        else {
            // We got a variable
            return .variable(ident)
        }
    }
    
    /// Rule:
    ///
    ///     primary -> NUMBER | STRING | VARIABLE_OR_CALL | "(" expression ")" ;
    ///
    func primary() throws (ExpressionSyntaxError) -> ExpressionAST? {
        if let node = number() {
            return node
        }
        else if let node = try variable_or_call() {
            return node
        }

        else if let lparen = accept(.leftParen) {
            if let expr = try expression() {
                guard let rparen = accept(.rightParen) else {
                    throw .missingRightParenthesis
                }
                return .parenthesis(expression: expr,
                                    openParen: lparen,
                                    closeParen: rparen)
            }
        }
        return nil
    }
    
    /// Rule:
    ///
    ///     unary -> "-" unary | primary ;
    ///
    func unary() throws (ExpressionSyntaxError) -> ExpressionAST? {
        // TODO: Add '!'
        if let op = `operator`("-") {
            guard let operand = try unary() else {
                throw .expressionExpected
            }
            return .unaryOperator(operator: op, operand: operand)
        }
        else {
            return try primary()
        }
        
    }

    /// Rule:
    ///
    ///     exponent -> unary ( "^" unary )* ;
    ///
    func exponent() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard var left = try unary() else {
            return nil
        }
        
        while let op = `operator`("^") {
            guard let right = try unary() else {
                throw .expressionExpected
            }
            left = .binaryOperator(operator: op, left: left, right: right)
        }
        
        return left
    }

    /// Rule:
    ///
    ///     factor -> unary ( ( "/" | "*" ) unary )* ;
    ///
    func factor() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard var left = try exponent() else {
            return nil
        }
        
        while let op = `operator`("*") ?? `operator`("/") ?? `operator`("%") {
            guard let right = try exponent() else {
                throw .expressionExpected
            }
            left = .binaryOperator(operator: op, left: left, right: right)
        }
        
        return left
    }

    /// Rule:
    ///
    ///     term -> factor ( ( "-" | "+" ) factor )* ;
    ///
    func term() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard var left = try factor() else {
            return nil
        }
        
        while let op = `operator`("+") ?? `operator`("-") {
            guard let right = try factor() else {
                throw .expressionExpected
            }
            left = .binaryOperator(operator: op, left: left, right: right)
        }
        
        return left
    }
    
    /// Rule:
    ///
    ///     term -> factor ( ( "-" | "+" ) factor )* ;
    ///
    func comparison_expression() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard var left = try term() else {
            return nil
        }
        
        while let op = `operator`("<")
                ?? `operator`("<=")
                ?? `operator`(">")
                ?? `operator`(">="){
            guard let right = try term() else {
                throw .expressionExpected
            }
            left = .binaryOperator(operator: op, left: left, right: right)
        }
        
        return left
    }

    /// Rule:
    ///
    ///     term -> factor ( ( "-" | "+" ) factor )* ;
    ///
    func equality_expression() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard var left = try comparison_expression() else {
            return nil
        }
        
        while let op = `operator`("==") ?? `operator`("!=") {
            guard let right = try comparison_expression() else {
                throw .expressionExpected
            }
            left = .binaryOperator(operator: op, left: left, right: right)
        }
        
        return left
    }

    func expression() throws (ExpressionSyntaxError) -> ExpressionAST? {
        return try equality_expression()
    }
    
    
    /// Parse the expression and return an unbound arithmetic expression.
    ///
    /// - Throws: `SyntaxError` when there is an issue with the expression.
    public func parse() throws (ExpressionSyntaxError) -> UnboundExpression {
        guard let expr = try expression() else {
            throw .expressionExpected
        }
        
        if currentToken?.type != .empty {
            throw .unexpectedToken
        }
        return expr.toExpression()
    }
    
}
