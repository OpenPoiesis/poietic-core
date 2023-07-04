//
//  ASTExpression.swift
//  
//
//  Created by Stefan Urbanek on 12/07/2022.
//

// TODO: Make this into a proper public AST representation that can be modified

protocol AST {
    var tokens: [Token] { get }
    var fullText: String { get }
}

/// AST node for arithmetic expression.
struct ExpressionAST: AST {
    
    /// Type defining specific kind of the expression AST node
    indirect enum Kind {
        case int(String)
        case double(String)
        case variable(String)
        case parenthesis(ExpressionAST)
        case unary(String, ExpressionAST)
        case binary(String, ExpressionAST, ExpressionAST)
        case function(String, [ExpressionAST])
    }
    
    /// Specific kind of the expression AST node
    public let kind: Kind
    
    /// List of tokens from which the AST node
    public let tokens: [Token]
    
    /// Create an expression AST node
    public init(_ kind: Kind, tokens: [Token]) {
        self.kind = kind
        self.tokens = tokens
    }
    
    /// Returns reproduction of the original source from which this
    /// node was parsed.
    ///
    var fullText: String {
        tokens.map { $0.fullText }.joined()
    }

    /// List of tokens representing variables in the expressions.
    ///
    var variables: [String] {
        switch kind {
        case     .int(_):
            return []
        case     .double(_):
            return []
        case let .function(_, args):
            return args.flatMap { $0.variables }
        case let .variable(name):
            return [name]
        case let .parenthesis(expr):
            return expr.variables
        case let .unary(_, operand):
            return operand.variables
        case let .binary(_, left, right):
            return left.variables + right.variables
        }
    }

    
    /// Converts the AST to an actual expression object.
    ///
    /// - Note: The constructed AST is expected to be valid.
    ///
    func toExpression() -> UnboundExpression {
        switch kind {
        case let .int(text):
            var sanitizedString = text
            sanitizedString.removeAll { $0 == "_" }
            guard let intValue = Int(sanitizedString) else {
                fatalError("Unable to convert supposedly integer token '\(text)' to actual Int")
            }
            return .value(intValue)

        case let .double(text):
            var sanitizedString = text
            sanitizedString.removeAll { $0 == "_" }
            guard let doubleValue = Double(sanitizedString) else {
                fatalError("Unable to convert supposedly double token '\(text)' to actual Double")
            }
            return .value(doubleValue)

        case let .function(name, args):
            let argExpressions = args.map { $0.toExpression() }
            return .function(name, argExpressions)

        case let .variable(name):
            return .variable(name)

        case let .parenthesis(expr):
            return expr.toExpression()

        case let .unary(op, operand):
            return .unary(op, operand.toExpression())

        case let .binary(op, left, right):
            return .binary(op, left.toExpression(), right.toExpression())
        }
    }

}
