//
//  NumericExpressionEvaluator.swift
//  
//
//  Created by Stefan Urbanek on 28/05/2022.
//

public enum ExpressionError: Error, CustomStringConvertible {
    case unknownVariable(String)
    case unknownFunction(String)
    case tooManyArguments
    case missingArguments
    // TODO: Remove
    case invalidNumberOfArguments(Int, Int)
    
    // TODO: Add argument name
    case argumentTypeMismatch(Int, String)
    
    public var description: String {
        switch self {
        case let .unknownVariable(name):
            "Unknown variable '\(name)'"
        case let .unknownFunction(name):
            "Unknown function '\(name)'"
        case .tooManyArguments:
            "Too many arguments"
        case .missingArguments:
            "Missing arguments"
        case .invalidNumberOfArguments:
            "Invalid number of arguments"
        case let .argumentTypeMismatch(number, expected):
            "Invalid type of argument number \(number). Expected: \(expected)"
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

extension ArithmeticExpression
where V: TypedValue, F: Function {
    public var valueType: ValueType {
        switch self {
        case let .value(value): value.valueType
        case let .binary(op, _, _): op.signature.returnType
        case let .unary(op, _): op.signature.returnType
        case let .function(fun, _): fun.signature.returnType
        case let .variable(variable): variable.valueType
        }
    }

}

/// Bind an expression to concrete variable references.
///
/// - Parameters:
///     - expression: Unbound arithmetic expression, where the function and
///       variable references are strings.
///     - variables: Dictionary of variables where the keys are variable names
///       and the values are (bound) references to the variables.
///     - functions: Dictionary of functions and operators where the keys are
///       function names and the values are objects representing functions.
///       See the list below of special function names that represent operators.
///
/// The operators are functions with special names. The following list contains
/// the names of the operators:
///
/// - `__add__` – binary addition operator `+`
/// - `__sub__` – binary subtraction operator `-`
/// - `__mul__` – binary multiplication operator `*`
/// - `__div__` – binary division operator `/`
/// - `__mod__` – binary modulo operator `%`
/// - `__neg__` – unary negation operator `-`
///
/// - Note: The operator names are similar to the operator method names in
///   Python.
///
/// - Returns: ``ArithmeticExpression`` where variables and functions are resolved.
/// - Throws: ``ExpressionError`` when a variable or a function is not known
///  or when the function arguments do not match the function's requirements.
///
public func bindExpression<V: TypedValue>(
    _ expression: UnboundExpression,
    variables: [String:V],
    functions: [String:Function]) throws -> ArithmeticExpression<V, Function> {
    
    switch expression {
    case let .value(value):
        return .value(value)

    case let .unary(op, operand):
        let funcName: String = switch op {
        case "-": "__neg__"
        default: fatalError("Unknown unary operator: '\(op)'. Hint: check the expression parser.")
        }

        guard let function = functions[funcName] else {
            fatalError("No function '\(funcName)' for unary operator: '\(op)'. Hint: Make sure it is defined in the builtin function list.")
        }

        let boundOperand = try bindExpression(operand,
                                              variables: variables,
                                              functions: functions)
        
        let result = function.signature.validate([boundOperand.valueType])
        switch result {
        case .invalidNumberOfArguments:
            throw ExpressionError.invalidNumberOfArguments(1,
                                                         function.signature.minimalArgumentCount)
        case .typeMismatch(_):
            throw ExpressionError.argumentTypeMismatch(1, "int or double")
        default:
            return .unary(function, boundOperand)
        }
        
        
    case let .binary(op, lhs, rhs):
        let funcName: String = switch op {
        case "+": "__add__"
        case "-": "__sub__"
        case "*": "__mul__"
        case "/": "__div__"
        case "%": "__mod__"
        default: fatalError("Unknown binary operator: '\(op)'. Internal hint: check the expression parser.")
        }
        
        guard let function = functions[funcName] else {
            fatalError("No function '\(funcName)' for binary operator: '\(op)'. Internal hint: Make sure it is defined in the builtin function list.")
        }

        let lBound = try bindExpression(lhs, variables: variables, functions: functions)
        let rBound = try bindExpression(rhs, variables: variables, functions: functions)

        let result = function.signature.validate([lBound.valueType, rBound.valueType])
        switch result {
        case .invalidNumberOfArguments:
            throw ExpressionError.invalidNumberOfArguments(2,
                                                         function.signature.minimalArgumentCount)
        case .typeMismatch(let index):
            // TODO: We need all indices
            throw ExpressionError.argumentTypeMismatch(index.first! + 1, "int or double")
        default: //
            return .binary(function, lBound, rBound)
        }

    case let .function(name, arguments):
        guard let function = functions[name] else {
            throw ExpressionError.unknownFunction(name)
        }
        
        let boundArgs = try arguments.map {
            try bindExpression($0, variables: variables, functions: functions)
        }

        let types = boundArgs.map { $0.valueType }
        let result = function.signature.validate(types)

        switch result {
        case .invalidNumberOfArguments:
            throw ExpressionError.invalidNumberOfArguments(arguments.count,
                                          function.signature.minimalArgumentCount)
        case .typeMismatch(let index):
            // TODO: We need all indices
            throw ExpressionError.argumentTypeMismatch(index.first! + 1, "int or double")
        default: //
            return .function(function, boundArgs)
        }

    case let .variable(name):
        guard let ref = variables[name] else {
            throw ExpressionError.unknownVariable(name)
        }
        return .variable(ref)
    }
}

