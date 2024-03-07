//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/03/2024.
//

import Foundation

//public class IFFunction {
//    
//    public let name: String = "if"
//    public let signature: Signature = Signature(
//        [
//            FunctionArgument("condition", type: .concrete(.bool)),
//            FunctionArgument("if_true", type: .any),
//            FunctionArgument("if_false", type: .any)
//        ]
//    )
//    public func apply(_ arguments: [Variant]) throws -> Variant {
//        fatalError("Nope")
//    }
//    
//    public func resultType(_ argumentTypes: [ValueType]) throws -> ValueType? {
//        guard argumentTypes.count == 2 || argumentTypes.count == 3 else {
//            if argumentTypes.count < 2 {
//                throw ExpressionError.missingArguments
//            }
//            else {
//                throw ExpressionError.tooManyArguments
//            }
//        }
//        fatalError("Nope")
//    }
//}

/// List of built-in binary comparison operators.
///
/// The operators:
///
/// - `__eq__` is `==`
/// - `__neq__` is `!=`
/// - `__gt__` is `>`
/// - `__ge__` is `>=`
/// - `__lt__` is `<`
/// - `__le__` is `<=`
///
/// - SeeAlso: ``bindExpression(_:variables:functions:)``
///
public let BuiltinComparisonOperators: [Function] = [
    .Comparison("__eq__") { (lhs, rhs) in
        return lhs == rhs
    },
    .Comparison("__neq__") { (lhs, rhs) in
        return lhs != rhs
    },
    .Comparison("__lt__") { (lhs, rhs) in
        return try lhs < rhs
    },
    .Comparison("__le__") { (lhs, rhs) in
        return try lhs <= rhs
    },
    .Comparison("__gt__") { (lhs, rhs) in
        return try lhs > rhs
    },
    .Comparison("__ge__") { (lhs, rhs) in
        return try lhs >= rhs
    },
]

public let BuiltinFunctions: [Function] = [
    Function(name: "if",
             signature: Signature(
                [
                    FunctionArgument("condition", type: .bool),
                    FunctionArgument("if_true", type: .double),
                    FunctionArgument("if_false", type: .double),
                ],
                returns: .double
             ),
             body: builtinIfFunctionBody
            ),
]

func builtinIfFunctionBody(_ arguments: [Variant]) throws -> Variant {
    guard arguments.count == 3 else {
        fatalError("Invalid number of arguments (\(arguments.count)) for `if` function. Hint: Expression binding seems to be broken.")
    }
    let condition = arguments[0]
    let ifTrue = arguments[1]
    let ifFalse = arguments[2]
    
    if try condition.boolValue() {
        return ifTrue
    }
    else {
        return ifFalse
    }
}
