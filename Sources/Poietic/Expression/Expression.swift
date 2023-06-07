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
public typealias UnboundExpression = ArithmeticExpression<String, String>

/// Arithmetic expression.
///
/// Represents components of an arithmetic expression: values, variables,
/// operators and functions.
///
public indirect enum ArithmeticExpression<V,F> {
    // TODO: Remove generic
    public typealias VariableReference = V
    public typealias FunctionReference = F
    // Literals
    /// `NULL` literal
    case null

    /// Integer number literal
    case value(any ValueProtocol)

    /// Binary operator
    case binary(FunctionReference, ArithmeticExpression<V,F>, ArithmeticExpression<V,F>)
    
    /// Unary operator
    case unary(FunctionReference, ArithmeticExpression<V,F>)

    /// Function with multiple expressions as arguments
    case function(FunctionReference, [ArithmeticExpression<V,F>])

    /// Variable reference
    case variable(VariableReference)

    /// List of children from which the expression is composed. Does not go
    /// to underlying table expressions.
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
        case .null: return []
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

extension ArithmeticExpression: Equatable where F:Equatable, V:Equatable {
    public static func ==(left: ArithmeticExpression, right: ArithmeticExpression) -> Bool {
        switch (left, right) {
        case (.null, .null): return true
        case let(.value(lval), .value(rval)) where lval.isEqual(to: rval): return true
        case let(.binary(lop, lv1, lv2), .binary(rop, rv1, rv2))
                    where lop == rop && lv1 == rv1 && lv2 == rv2: return true
        case let(.unary(lop, lv), .unary(rop, rv))
                    where lop == rop && lv == rv: return true
        case let(.variable(lval), .variable(rval)) where lval == rval: return true
        case let(.function(lname, largs), .function(rname, rargs))
                    where lname == rname && largs == rargs: return true
        default:
            return false
        }
    }
}

extension ArithmeticExpression: ExpressibleByStringLiteral {
    public init(stringLiteral value: String.StringLiteralType) {
        self = .value(value)
    }
    public init(extendedGraphemeClusterLiteral value:
            String.ExtendedGraphemeClusterLiteralType){
        self = .value(value)
    }
    public init(unicodeScalarLiteral value: String.UnicodeScalarLiteralType) {
        self = .value(value)
    }
}

// FIXME: Do we still need these? Remove this pseudo-convenience!

extension String: ExpressionConvertible {
    public var toExpression: UnboundExpression { return .value(self) }
}

extension ArithmeticExpression: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int.IntegerLiteralType) {
        self = .value(value)
    }
}

extension Int: ExpressionConvertible {
    public var toExpression: UnboundExpression { return .value(self) }
}

extension ArithmeticExpression: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool.BooleanLiteralType){
        self = .value(value)
    }
}

extension Bool: ExpressionConvertible {
    public var toExpression: UnboundExpression { return .value(self) }
}

extension ArithmeticExpression: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
