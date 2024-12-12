//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/03/2024.
//

extension Function {
    // Comparison
    
    nonisolated(unsafe)
    public static let IsEqual = Function(comparison: "__eq__") { $0 == $1 }
    nonisolated(unsafe)
    public static let IsNotEqual = Function(comparison: "__neq__") { $0 != $1 }
    nonisolated(unsafe)
    public static let LessThan = Function(comparison: "__lt__") { $0 < $1 }
    nonisolated(unsafe)
    public static let LessOrEqual = Function(comparison: "__le__") { $0 <= $1 }
    nonisolated(unsafe)
    public static let GreaterThan = Function(comparison: "__gt__") { $0 > $1 }
    nonisolated(unsafe)
    public static let GreaterOrEqual = Function(comparison: "__ge__") { $0 >= $1 }
    
    nonisolated(unsafe)
    public static let ComparisonOperators: [Function] = [
        IsEqual,
        IsNotEqual,
        LessThan,
        LessOrEqual,
        GreaterThan,
        GreaterOrEqual
    ]
    
    // Boolean
    
    /// Boolean conditional function.
    ///
    /// The function takes three arguments:
    /// - `condition`: a boolean value
    /// - `if_true`: a value used when the `condition` is _true_
    /// - `if_false`: a value used when the `condition` is _false_
    ///
    nonisolated(unsafe)
    public static let IfFunction = Function(
        name: "if",
        signature: Signature(
            [
                FunctionArgument("condition", type: .bool),
                FunctionArgument("if_true", type: .double),
                FunctionArgument("if_false", type: .double),
            ],
            returns: .double
        ),
        body: _builtinIfFunctionBody
    )
    
    /// Logical negation of a boolean value.
    ///
    nonisolated(unsafe)
    public static let BooleanNot = Function(
        name: "not",
        signature: Signature([FunctionArgument("value", type: .bool)], returns: .double),
        body: _builtinNotFunctionBody
    )
    
    /// Logical _OR_ for two or more arguments.
    ///
    nonisolated(unsafe)
    public static let BooleanOr = Function(booleanVariadic: "or") {
        $0.reduce(false, { x, y in x || y })
    }
    
    /// Logical _AND_ for two or more arguments.
    ///
    nonisolated(unsafe)
    public static let BooleanAnd = Function(booleanVariadic: "and") {
        $0.reduce(true, { x, y in x && y })
    }

    nonisolated(unsafe)
    public static let BooleanFunctions: [Function] = [
        IfFunction,
        BooleanNot,
        BooleanOr,
        BooleanAnd
    ]
}

fileprivate func _builtinIfFunctionBody(_ arguments: [Variant]) throws (FunctionError) -> Variant {
    guard arguments.count == 3 else {
        throw .invalidNumberOfArguments(arguments.count)
    }
    let condition: Bool
    do {
        condition = try arguments[0].boolValue()
    }
    catch {
        throw .invalidArgument(0, error)
    }
    
    if condition {
        return arguments[1]
    }
    else {
        return arguments[2]
    }
}

fileprivate func _builtinNotFunctionBody(_ arguments: [Variant]) throws (FunctionError) -> Variant {
    guard arguments.count != 1 else {
        throw .invalidNumberOfArguments(arguments.count)
    }

    let value: Bool
    do {
        value = try arguments[0].boolValue()
    }
    catch {
        throw .invalidArgument(0, error)
    }

    return Variant(!value)
}
