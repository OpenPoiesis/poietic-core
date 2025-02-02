//
//  ASTExpression.swift
//  
//
//  Created by Stefan Urbanek on 12/07/2022.
//



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
            return token.fullText
        case let .doubleLiteral(token):
            return token.fullText
        case let .variable(token):
            return token.fullText
        case let .functionArgument(argument: argument, comma: comma):
            if let comma {
                return argument.fullText + comma.fullText
            }
            else {
                return argument.fullText
            }
        case let .functionCall(name: name, arguments: arguments, openParen: openParen, closeParen: closeParen):
            return name.fullText + openParen.fullText + arguments.map(\.fullText).joined() + closeParen.fullText
        case let .unaryOperator(operator: op, operand: operand):
            return op.fullText + operand.fullText
        case let .binaryOperator(operator: op, left: left, right: right):
            return left.fullText + op.fullText + right.fullText
        case let .parenthesis(expression: expression, openParen: openParen, closeParen: closeParen):
            return openParen.fullText + expression.fullText + closeParen.fullText
        }
    }

}
