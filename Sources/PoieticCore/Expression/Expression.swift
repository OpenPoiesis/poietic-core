//
//  Expression.swift
//  
//
//  Created by Stefan Urbanek on 26/05/2022.
//

/// Type alias for an expression where the variables and functions are
/// represented by a string - typically their names.
///
/// This type of expression is created by the parser:
/// ``ExpressionParser/parse()``.
///
public typealias UnboundExpression = ArithmeticExpression<String, String>

/// Arithmetic expression.
///
/// Represents components of an arithmetic expression: values, variables,
/// operators and functions.
///
/// - SeeAlso: ``ExpressionParser``, ``UnboundExpression``
///
public indirect enum ArithmeticExpression<V, F> {
    // TODO: Use operator table for operators
    public typealias LiteralValue = Variant

    /// Type of a reference to a variable.
    ///
    public typealias VariableReference = V

    /// Type of a reference to a function, including functions representing
    /// operators.
    ///
    public typealias FunctionReference = F

    /// Literal value.
    case value(LiteralValue)

    /// Variable reference.
    case variable(VariableReference)

    /// Unary operator.
    case unary(FunctionReference, Self)

    /// Binary operator.
    case binary(FunctionReference, Self, Self)
    
    /// Function with multiple expressions as arguments
    case function(FunctionReference, [Self])

    /// List of children from which the expression is composed. Does not go
    /// to underlying table expressions.
    ///
    public var children: [ArithmeticExpression] {
        switch self {
        case let .unary(_, expr): return [expr]
        case let .binary(_, lhs, rhs): return [lhs, rhs]
        case let .function(_, exprs): return exprs
        default: return []
        }
    }

    /// List of all variables that the expression and its children reference
    public var allVariables: [VariableReference] {
        // TODO: Remove duplicities.
        switch self {
        case .value(_): return []
        case let .variable(ref):
            return [ref]
        case let .unary(_, expr):
            return expr.allVariables
        case let .binary(_, lhs, rhs):
            return lhs.allVariables + rhs.allVariables
        case let .function(_, arguments):
            return arguments.flatMap { $0.allVariables }
        }
    }
}


extension ArithmeticExpression
where V: CustomStringConvertible, F: CustomStringConvertible  {
    public var description: String {
        switch self {
        case let .value(value): return value.description
        case let .variable(ref): return ref.description
        case let .binary(fun, lhs, rhs): return "\(lhs) \(fun) \(rhs)"
        case let .unary(fun, op): return "\(op)\(fun)"
        case let .function(fun, args):
            let argstr = args.map { $0.description }.joined(separator: ", ")
            return "\(fun)(\(argstr))"
        }
    }
}


extension ArithmeticExpression: Equatable where F:Equatable, V:Equatable {
    public static func ==(left: ArithmeticExpression, right: ArithmeticExpression) -> Bool {
        switch (left, right) {
        case let(.value(lval), .value(rval)) where lval == rval: true
        case let(.variable(lval), .variable(rval)) where lval == rval: true
        case let(.unary(lop, lv), .unary(rop, rv))
                    where lop == rop && lv == rv: true
        case let(.binary(lop, lv1, lv2), .binary(rop, rv1, rv2))
                    where lop == rop && lv1 == rv1 && lv2 == rv2: true
        case let(.function(lname, largs), .function(rname, rargs))
                    where lname == rname && largs == rargs: true
        default:
            false
        }
    }
}
