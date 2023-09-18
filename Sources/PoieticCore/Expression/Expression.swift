//
//  Expression.swift
//  
//
//  Created by Stefan Urbanek on 26/05/2022.
//

public protocol ExpressionConvertible {
    var toExpression: UnboundExpression { get }
}

// TODO: Design sketch
public typealias UnboundExpression = ArithmeticExpression<ForeignValue, String, String>

/// Arithmetic expression.
///
/// Represents components of an arithmetic expression: values, variables,
/// operators and functions.
///
/// The type arguments:
///     - ``LiteralValue`` (`L`): Type of a literal.
///     - ``VariableReference`` (`V`): Type of a reference to a variable.
///     - ``FunctionReference`` (`F`): Type of a reference to a function,
///         including functions representing operators.
///
public indirect enum ArithmeticExpression<L, V, F> {
    public typealias LiteralValue = L
    public typealias VariableReference = V
    public typealias FunctionReference = F
    // Literals
    /// Literal value.
    case value(LiteralValue)

    /// Binary operator.
    case binary(FunctionReference, Self, Self)
    
    /// Unary operator.
    case unary(FunctionReference, Self)

    /// Function with multiple expressions as arguments
    case function(FunctionReference, [Self])

    /// Variable reference.
    case variable(VariableReference)

    /// List of children from which the expression is composed. Does not go
    /// to underlying table expressions.
    ///
    public var children: [ArithmeticExpression] {
        switch self {
        case let .binary(_, lhs, rhs): return [lhs, rhs]
        case let .unary(_, expr): return [expr]
        case let .function(_, exprs): return exprs
        default: return []
        }
    }

    /// List of all variables that the expression and its children reference
    public var allVariables: [VariableReference] {
        switch self {
        case .value(_): return []
        case let .variable(ref):
            return [ref]
        case let .binary(_, lhs, rhs):
            return lhs.allVariables + rhs.allVariables
        case let .unary(_, expr):
            return expr.allVariables
        case let .function(_, arguments):
            return arguments.flatMap { $0.allVariables }
        }
    }
}


extension ArithmeticExpression: Equatable where L:Equatable, F:Equatable, V:Equatable {
    public static func ==(left: ArithmeticExpression, right: ArithmeticExpression) -> Bool {
        switch (left, right) {
        case let(.value(lval), .value(rval)) where lval == rval: true
        case let(.binary(lop, lv1, lv2), .binary(rop, rv1, rv2))
                    where lop == rop && lv1 == rv1 && lv2 == rv2: true
        case let(.unary(lop, lv), .unary(rop, rv))
                    where lop == rop && lv == rv: true
        case let(.variable(lval), .variable(rval)) where lval == rval: true
        case let(.function(lname, largs), .function(rname, rargs))
                    where lname == rname && largs == rargs: true
        default:
            false
        }
    }
}
