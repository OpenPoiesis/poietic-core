//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/03/2024.
//

/// List of built-in binary comparison operators.
///
/// The operators:
///
/// - `__eq__` is `==`
/// - `__ne__` is `!=`
/// - `__gt__` is `>`
/// - `__ge__` is `>=`
/// - `__lt__` is `<`
/// - `__le__` is `<=`
///
nonisolated(unsafe)  public let BuiltinComparisonOperators: [Function] = [
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


/// List of all builtin functions provided by the Core.
///
/// The list includes all functions from ``BuiltinComparisonOperators`` with
/// addition of:
///
/// - `if(condition, if_true, if_false)`
/// - `not(value)` as logical negation
/// - `or(...)` as logical OR
/// - `and(...)` as logical AND
/// 
nonisolated(unsafe)  public let BuiltinFunctions: [Function] = BuiltinComparisonOperators + [
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
    Function(
        name: "not",
        signature: Signature([FunctionArgument("value", type: .bool)],
                             returns: .double),
        body: builtinNotFunctionBody
    ),
    Function.BooleanVariadic("or") { args in
        args.reduce(false, { x, y in x || y })
    },
    Function.BooleanVariadic("and") { args in
        args.reduce(true, { x, y in x && y })
    },

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

func builtinNotFunctionBody(_ arguments: [Variant]) throws -> Variant {
    guard arguments.count != 1 else {
        fatalError("Invalid number of arguments (\(arguments.count)) for `not` function, expected only 1. Hint: Expression binding seems to be broken.")
    }
    return Variant(!(try arguments[0].boolValue()))
}
