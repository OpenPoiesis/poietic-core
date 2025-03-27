//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 27/05/2022.
//

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
    ///     factor -> unary ( ( "/" | "*" ) unary )* ;
    ///
    func factor() throws (ExpressionSyntaxError) -> ExpressionAST? {
        guard var left = try unary() else {
            return nil
        }
        
        while let op = `operator`("*") ?? `operator`("/") ?? `operator`("%") {
            guard let right = try unary() else {
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
