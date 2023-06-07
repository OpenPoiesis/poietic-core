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
public class ExpressionParser {
    let lexer: Lexer
    var currentToken: Token?
    
    /// Creates a new parser using an expression lexer.
    ///
    public init(lexer: Lexer) {
        self.lexer = lexer
        advance()
    }
    
    /// Creates a new parser for an expression source string.
    ///
    public convenience init(string: String) {
        self.init(lexer: Lexer(string: string))
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
    func accept(_ type: TokenType) -> Token? {
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
    func `operator`(_ op: String) -> Token? {
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
    func identifier() -> Token? {
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
            return ExpressionAST(.int(token.text),
                                 tokens: [token])
        }
        else if let token = accept(.float) {
            return ExpressionAST(.double(token.text),
                                 tokens: [token])
        }
        else {
            return nil
        }
    }
    
    /// Rule:
    ///
    ///     variable_call -> IDENTIFIER ["(" ARGUMENTS ")"]
    ///
    func variable_or_call() throws -> ExpressionAST? {
        guard let ident = identifier() else {
            return nil
        }
        var tokens: [Token] = []
        tokens.append(ident)
        
        // FIXME: Preserve the paren tokens
        if let lpar = accept(.leftParen) {
            tokens.append(lpar)

            var arguments: [ExpressionAST] = []
            repeat {
                if let arg = try expression() {
                    arguments.append(arg)
                    tokens += arg.tokens
                }
                guard let comma = accept(.comma) else {
                    break
                }
                tokens.append(comma)
            } while true

            guard let rpar = accept(.rightParen) else {
                throw SyntaxError.missingRightParenthesis
            }
            tokens.append(rpar)
            
            return ExpressionAST(.function(ident.text, arguments), tokens: tokens)
        }
        else {
            // We got a variable
            return ExpressionAST(.variable(ident.text), tokens: tokens)
        }
    }
    
    /// Rule:
    ///
    ///     primary -> NUMBER | STRING | VARIABLE_OR_CALL | "(" expression ")" ;
    ///
    func primary() throws -> ExpressionAST? {
        // TODO: true, false, nil
        if let node = number() {
            return node
        }
        else if let node = try variable_or_call() {
            return node
        }

        else if let lparen = accept(.leftParen) {
            var tokens: [Token] = []
            tokens.append(lparen)
            if let expr = try expression() {
                tokens += expr.tokens
                
                guard let rparen = accept(.rightParen) else {
                    throw SyntaxError.missingRightParenthesis
                }
                tokens.append(rparen)
                
                return ExpressionAST(.parenthesis(expr), tokens: tokens)
            }
        }
        return nil
    }
    
    /// Rule:
    ///
    ///     unary -> "-" unary | primary ;
    ///
    func unary() throws -> ExpressionAST? {
        // TODO: Add '!'
        if let op = `operator`("-") {
            guard let right = try unary() else {
                throw SyntaxError.expressionExpected
            }
            return ExpressionAST(.unary(op.text, right),
                                 tokens: [op] + right.tokens)
        }
        else {
            return try primary()
        }
        
    }

    /// Rule:
    ///
    ///     factor -> unary ( ( "/" | "*" ) unary )* ;
    ///
    func factor() throws -> ExpressionAST? {
        guard var left = try unary() else {
            return nil
        }
        
        while let op = `operator`("*") ?? `operator`("/") ?? `operator`("%"){
            guard let right = try unary() else {
                throw SyntaxError.expressionExpected
            }
            left = ExpressionAST(.binary(op.text, left, right),
                                 tokens: left.tokens + [op] + right.tokens)
        }
        
        return left
    }

    /// Rule:
    ///
    ///     term -> factor ( ( "-" | "+" ) factor )* ;
    ///
    func term() throws -> ExpressionAST? {
        guard var left = try factor() else {
            return nil
        }
        
        while let op = `operator`("+") ?? `operator`("-") {
            guard let right = try factor() else {
                throw SyntaxError.expressionExpected
            }
            left = ExpressionAST(.binary(op.text, left, right),
                                 tokens: left.tokens + [op] + right.tokens)
        }
        
        return left
    }
    
    func expression() throws -> ExpressionAST? {
        return try term()
    }
    
    
    /// Parse the expression and return an unbound arithmetic expression.
    ///
    /// - Throws: `SyntaxError` when there is an issue with the expression.
    public func parse() throws -> UnboundExpression {
        guard let expr = try expression() else {
            throw SyntaxError.expressionExpected
        }
        
        if currentToken?.type != .empty {
            throw SyntaxError.unexpectedToken
        }
        return expr.toExpression()
    }
    
}
