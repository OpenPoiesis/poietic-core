//
//  ASTExpression.swift
//  
//
//  Created by Stefan Urbanek on 12/07/2022.
//


/// Protocol for expression syntax nodes.
///
public protocol ExpressionSyntax {
    /// Get a full text of the node that represents the expression.
    /// The full text must be parseable back to the equivalent node.
    ///
    var fullText: String { get }
}

extension ExpressionSyntax {
    /// Converts an expression syntax node into an unbound arithmetic
    /// expression.
    ///
    /// - SeeAlso: ``UnboundExpression``
    ///
    public func toExpression() -> UnboundExpression {
        switch self {
        case let node as LiteralSyntax:
            switch node.type {
            case .int:
                var sanitizedNumber = node.literal.text
                sanitizedNumber.removeAll { $0 == "_" }
                guard let value = Int(sanitizedNumber) else {
                    fatalError("Unable to convert integer token '\(node.literal.text)' to actual Int. Broken lexer?")
                }
                return .value(Variant(value))
            case .double:
                var sanitizedNumber = node.literal.text
                sanitizedNumber.removeAll { $0 == "_" }
                guard let value = Double(sanitizedNumber) else {
                    fatalError("Unable to convert double token '\(node.literal.text)' to actual Double. Broken lexer?")
                }
                return .value(Variant(value))
            }

        case let node as VariableSyntax:
            return .variable(String(node.variable.text))

        case let node as UnaryOperatorSyntax:
            let operand = node.operand.toExpression()
            let op = node.op.text
            return .unary(String(op), operand)

        case let node as BinaryOperatorSyntax:
            let op = node.op.text
            let left = node.leftOperand.toExpression()
            let right = node.rightOperand.toExpression()
            return .binary(String(op), left, right)

        case let node as FunctionCallSyntax:
            let name = node.name.text
            let args = node.arguments.arguments.map {
                $0.argument.toExpression()
            }
            return .function(String(name), args)

        case let node as ParenthesisSyntax:
            return node.expression.toExpression()
        default:
            fatalError("Unknown syntax node: \(self). Internal hint: stray syntax node type generated by the expression parser.")
        }
    }
}

public final class LiteralSyntax: ExpressionSyntax {
    public enum LiteralType {
        case int
        case double
    }
    
    public let type: LiteralType
    public let literal: ExpressionToken

    public var fullText: String { literal.fullText }
    
    public init(type: LiteralType, literal: ExpressionToken) {
        self.type = type
        self.literal = literal
    }
}

public final class VariableSyntax: ExpressionSyntax {
    public let variable: ExpressionToken

    public var fullText: String { variable.fullText }

    public init(variable: ExpressionToken) {
        self.variable = variable
    }
}

public final class FunctionArgumentSyntax: ExpressionSyntax {
    public let argument: any ExpressionSyntax
    public let trailingComma: ExpressionToken?
    
    public var fullText: String {
        if let comma = trailingComma {
            argument.fullText + comma.fullText
        }
        else {
            argument.fullText
        }
    }

    public init(argument: any ExpressionSyntax, trailingComma: ExpressionToken?) {
        self.argument = argument
        self.trailingComma = trailingComma
    }
}

public final class FunctionArgumentListSyntax: ExpressionSyntax {
    public let arguments: [FunctionArgumentSyntax]
    
    public var fullText: String { arguments.map { $0.fullText }.joined() }

    public init(arguments: [FunctionArgumentSyntax]) {
        self.arguments = arguments
    }
}

public final class FunctionCallSyntax: ExpressionSyntax {
    public let name: ExpressionToken
    public let leftParen: ExpressionToken
    public let arguments: FunctionArgumentListSyntax
    public let rightParen: ExpressionToken
    
    public var fullText: String {
        name.fullText + leftParen.fullText + arguments.fullText + rightParen.fullText
    }

    
    public init(name: ExpressionToken, leftParen: ExpressionToken, arguments: FunctionArgumentListSyntax, rightParen: ExpressionToken) {
        self.name = name
        self.leftParen = leftParen
        self.arguments = arguments
        self.rightParen = rightParen
    }
}

public final class UnaryOperatorSyntax: ExpressionSyntax {
    public let op: ExpressionToken
    public let operand: any ExpressionSyntax

    public var fullText: String {
        op.fullText + operand.fullText
    }
    
    public init(op: ExpressionToken, operand: any ExpressionSyntax) {
        self.op = op
        self.operand = operand
    }
}

public final class BinaryOperatorSyntax: ExpressionSyntax {
    public let leftOperand: any ExpressionSyntax
    public let op: ExpressionToken
    public let rightOperand: any ExpressionSyntax

    public var fullText: String {
        leftOperand.fullText + op.fullText + rightOperand.fullText
    }

    public init(leftOperand: any ExpressionSyntax, op: ExpressionToken, rightOperand: any ExpressionSyntax) {
        self.leftOperand = leftOperand
        self.op = op
        self.rightOperand = rightOperand
    }
}

public final class ParenthesisSyntax: ExpressionSyntax {
    public let leftParen: ExpressionToken
    public let expression: any ExpressionSyntax
    public let rightParen: ExpressionToken

    public var fullText: String {
        leftParen.fullText + expression.fullText + rightParen.fullText
    }

    public init(leftParen: ExpressionToken, expression: any ExpressionSyntax, rightParen: ExpressionToken) {
        self.leftParen = leftParen
        self.expression = expression
        self.rightParen = rightParen
    }
}
