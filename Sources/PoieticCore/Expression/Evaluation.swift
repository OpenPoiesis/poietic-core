//
//  Evaluator.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/08/2026.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Protocol for objects that look-up variables by name. Used for expression binding.
///
/// - SeeAlso: ``bindExpression(_:variables:)``, ``VariableValueLookup``
///
public protocol VariableNameLookup<Variable> {
    associatedtype Variable
    func variable(named name: String) -> Variable?
}

/// Protocol for objects that look-up variable values. Used for expression evaluation.
///
/// - SeeAlso: ``Evaluator/evaluate(expression:lookup:)``, ``VariableNameLookup``
public protocol VariableValueLookup<Variable> {
    associatedtype Variable
    func value(for variable: Variable) -> Variant
}

public protocol TypedVariable {
    var valueType: ValueType { get }
}

public enum EvaluationError: Error {
    case invalidNumber
    case valueError(ValueError)
    case functionError(String, FunctionError)
    // TODO: Add operator error, as "function +" makes no sense to ordinary users
}


/// Namespace for arithmetic expression evaluation.
///
public enum Evaluator {
    /// Bind an expression to concrete variable references.
    ///
    /// - Parameters:
    ///     - expression: Unbound arithmetic expression, where the function and
    ///       variable references are strings.
    ///     - variables: List of compiled state variables.
    ///
    /// - Note: The operator names are similar to the operator method names in
    ///   Python.
    ///
    /// - Returns: ``PoieticCore/ArithmeticExpression`` where variables and functions are resolved.
    /// - Throws: ``ExpressionError`` when a variable or a function is not known
    ///  or when the function arguments do not match the function's requirements.
    ///
    public static func bind<L: VariableNameLookup>(_ expression: UnboundExpression, variables: L)
    throws (ExpressionError)
    -> ArithmeticExpression<L.Variable, BuiltinFunction>
    where L.Variable: TypedVariable
    {
        switch expression {
        case let .value(value):
            return .value(value)

        case let .variable(name):
            guard let variable: L.Variable = variables.variable(named: name)
            else { throw ExpressionError.unknownVariable(name) }
            return .variable(variable)

        case let .unary(op, operand):
            let boundOperand = try bind(operand, variables: variables)
            return .unary(op, boundOperand)
            
        case let .binary(op, lhs, rhs):
            let lBound = try bind(lhs, variables: variables)
            let rBound = try bind(rhs, variables: variables)
            return .binary(op, lBound, rBound)

        case let .function(name, arguments):
            guard let function = BuiltinFunction(name: name) else {
                throw ExpressionError.unknownFunction(name)
            }
            var boundArgs: [ArithmeticExpression<L.Variable, BuiltinFunction>] = []

            for arg in arguments {
                let boundArg = try bind(arg, variables: variables)
                boundArgs.append(boundArg)
            }

            let types = boundArgs.map { $0.valueType }
            switch function.signature.validate(types) {
            case .invalidNumberOfArguments:
                throw .invalidNumberOfArguments(name, arguments.count, function.signature.minimalArgumentCount)
            case .typeMismatch(let mismatch):
                throw .argumentTypeMismatch(name, mismatch)
            case .ok: break
            }

            return .function(function, boundArgs)
        }
    }


    /// Evaluate an arithmetic expression using a variable lookup.
    ///
    /// - Parameters:
    ///     - expression: Arithmetic expression where variables are used as references to be
    ///       looked-up for the actual variable value.
    ///     - Variable look-up where variable from the expression is mapped to an actual
    ///       variant value.
    ///
    public static func evaluate<L: VariableValueLookup>(
        expression: ArithmeticExpression<L.Variable,BuiltinFunction>,
        lookup: L)
    throws (EvaluationError) -> Variant
    {
        switch expression {
        case let .value(value):
            return value

        case let .variable(variable):
            return lookup.value(for: variable)

        case let .binary(op, left, right):
            let leftValue = try Evaluator.evaluate(expression: left, lookup: lookup)
            let rightValue = try Evaluator.evaluate(expression: right, lookup: lookup)
            
            do {
                return try evaluate(binary: op, leftValue, rightValue)
            }
            catch {
                throw .functionError(op.symbol, error)
            }
            
        case let .unary(op, operand):
            let value = try Evaluator.evaluate(expression: operand, lookup: lookup)
            do {
                return try Evaluator.evaluate(unary: op, value)
            }
            catch {
                throw .functionError(op.symbol, error)
            }
            
        case let .function(function, arguments):
            let argValues = try arguments.map { expr throws (EvaluationError) in
                try Evaluator.evaluate(expression: expr, lookup: lookup)
            }
            do {
                return try Evaluator.evaluate(function: function, arguments: argValues)
            }
            catch {
                throw .functionError(function.name, error)
            }
        }
    }
    
    public static func evaluate(binary op: BinaryOperator, _ lhs: Variant, _ rhs: Variant)
    throws (FunctionError) -> Variant
    {
        let result: Variant
        switch op {
        // Comparison - equality
        case .isEqual:
            result = Variant(lhs == rhs)
        case .notEqual:
            result = Variant(lhs != rhs)
            
        // Numeric comparison
        case .lessThan:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs < rhs)
        case .greaterThan:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs > rhs)
        case .lessOrEqual:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs <= rhs)
        case .greaterOrEqual:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs >= rhs)
            
        // Binary numeric
        case .add:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs + rhs)
        case .subtract:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs - rhs)
        case .multiply:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs * rhs)
        case .divide:
            // Division by zero is handled by propagating through -Inf double values.
            // Makes the result invalid, but does not crash.
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs / rhs)
        case .modulo:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(lhs.truncatingRemainder(dividingBy: rhs))
        case .power:
            let (lhs, rhs): (Double, Double) = try castArguments(lhs, rhs)
            result = Variant(pow(lhs, rhs))
        }
        
        return result
    }
    
    public static func evaluate(unary op: UnaryOperator, _ operand: Variant)
    throws (FunctionError) -> Variant
    {
        let result: Variant
        switch op {
            // Comparison - equality
        case .negate:
            let arg: Double = try castArgument(operand)
            result = Variant(-arg)
        }
        
        return result
    }
    
    public static func evaluate(function: BuiltinFunction, arguments: [Variant])
    throws (FunctionError) -> Variant
    {
        let result: Variant
        switch function {
        // Boolean
        case .not:
            let arg: Bool = try castArguments(arguments)
            result = Variant(!arg)
        case .and:
            guard arguments.count >= 2 else { throw .invalidNumberOfArguments(1) }
            let args: [Bool] = try castArguments(arguments)
            var value = true
            for arg in args {
                value = value && arg
            }
            result = Variant(value)
        case .or:
            guard arguments.count >= 2 else { throw .invalidNumberOfArguments(1) }
            let args: [Bool] = try castArguments(arguments)
            var value = false
            for arg in args {
                value = value || arg
            }
            result = Variant(value)
        case .`if`:
            let (condition, trueValue, falseValue): (Bool, Variant, Variant) = try castArguments(arguments)
            result = condition ? trueValue : falseValue
        // Unary numeric
        case .abs:
            let arg: Double = try castArguments(arguments)
            result = Variant(arg.magnitude)
        case .floor:
            let arg: Double = try castArguments(arguments)
            result = Variant(arg.rounded(.down))
        case .ceiling:
            let arg: Double = try castArguments(arguments)
            result = Variant(arg.rounded(.up))
        case .round:
            let arg: Double = try castArguments(arguments)
            result = Variant(arg.rounded())
        case .exp:
            let arg: Double = try castArguments(arguments)
#if os(Linux)
            result = Variant(Glibc.exp(arg))
#else
            result = Variant(Darwin.exp(arg))
#endif
        case .sqrt:
            let arg: Double = try castArguments(arguments)
            result = Variant(arg.squareRoot())

        // Variadic numeric
        case .min:
            let values: [Double] = try castArguments(arguments)
            guard values.count > 0 else { throw .invalidNumberOfArguments(1) }
            result = Variant(values.min()!)
        case .max:
            let values: [Double] = try castArguments(arguments)
            guard values.count > 0 else { throw .invalidNumberOfArguments(1) }
            result = Variant(values.max()!)
        case .sum:
            let values: [Double] = try castArguments(arguments)
            result = Variant(values.reduce(0, { x, y in x + y }))
        }
                
        return result
    }
    
    // - MARK: - Argument Value Casting
    // Unary
    static func castArguments(_ arguments: [Variant]) throws (FunctionError) -> Double {
        guard arguments.count == 1 else { throw .invalidNumberOfArguments(arguments.count) }
        let first: Double

        do { first = try arguments[0].doubleValue() }
        catch { throw .invalidArgument(0, error) }

        return first
    }
    static func castArguments(_ arguments: [Variant]) throws (FunctionError) -> Bool {
        guard arguments.count == 1 else { throw .invalidNumberOfArguments(arguments.count) }
        let first: Bool

        do { first = try arguments[0].boolValue() }
        catch { throw .invalidArgument(0, error) }

        return first
    }

    static func castArgument(_ value: Variant) throws (FunctionError) -> Double {
        let result: Double

        do { result = try value.doubleValue() }
        catch { throw .invalidArgument(0, error) }

        return result
    }

    // Binary

    static func castArguments(_ lhs: Variant, _ rhs: Variant) throws (FunctionError) -> (Double, Double) {
        let resultLeft: Double
        let resultRight: Double

        do { resultLeft = try lhs.doubleValue() }
        catch { throw .invalidArgument(0, error) }

        do { resultRight = try rhs.doubleValue() }
        catch { throw .invalidArgument(1, error) }

        return (resultLeft, resultRight)
    }

    // Ternary
    static func castArguments(_ arguments: [Variant]) throws (FunctionError) -> (Bool, Variant, Variant) {
        guard arguments.count == 3 else { throw .invalidNumberOfArguments(arguments.count) }
        let first: Bool

        do { first = try arguments[0].boolValue() }
        catch { throw .invalidArgument(0, error) }

        return (first, arguments[1], arguments[2])
    }

    // Variadic
    static func castArguments(_ arguments: [Variant]) throws (FunctionError) -> [Double] {
        var result: [Double] = Array(repeating: 0, count: arguments.count)
        for (i, arg) in arguments.enumerated() {
            do { result[i] = try arg.doubleValue() }
            catch { throw .invalidArgument(i, error) }
        }
        return result
    }
    static func castArguments(_ arguments: [Variant]) throws (FunctionError) -> [Bool] {
        var result: [Bool] = Array(repeating: false, count: arguments.count)
        for (i, arg) in arguments.enumerated() {
            do { result[i] = try arg.boolValue() }
            catch { throw .invalidArgument(i, error) }
        }
        return result
    }

}

// TODO: Make ExpressionError DesignIssueConvertible
public enum ExpressionError: Error, CustomStringConvertible, Equatable {
    case unknownVariable(String)
    case unknownFunction(String)
    /// Invalid number of function arguments – (function name, given, expected)
    case invalidNumberOfArguments(String, Int, Int)
    case argumentTypeMismatch(String, [Int])
    
    public var description: String {
        switch self {
        case let .unknownVariable(name):
            "Unknown variable '\(name)'"
        case let .unknownFunction(name):
            "Unknown function '\(name)'"
        case let .invalidNumberOfArguments(function, given, expected):
            "Invalid number of arguments for function \(function), given \(given) expected \(expected)"
        case let .argumentTypeMismatch(function, _):
            "Invalid argument types for function '\(function)'."
        }
    }
}

extension ExpressionError: IssueProtocol {
    public var message: String { "Formula error: " + description }
    public var hints: [String] { ["Check the variables, types and functions in the formula and consult the manual for list of available variables and functions."] }
    
}

extension ArithmeticExpression where V:TypedVariable, F == BuiltinFunction {
    public var valueType: ValueType {
        switch self {
        case let .value(value): return value.valueType
        case let .variable(variable): return variable.valueType
        case let .unary(op, _): return op.resultType
        case let .binary(op, _, _): return op.resultType
        case let .function(function, _): return function.signature.returnType
        }
    }
}

