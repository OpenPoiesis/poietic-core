//
//  BuiltinFunction.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2026.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Error thrown when a function body is called.
///
/// - SeeAlso: ``Evaluator/evaluate(function:arguments:)``
///
public enum FunctionError: Error {
    case invalidArgument(Int, ValueError)
    case invalidNumberOfArguments(Int)
    case notComparableTypes(ValueType, ValueType)
}

/// Enumeration of functions that are provided for arithmetic expression evaluation.
///
/// - SeeAlso: ``Evaluator``, ``UnaryOperator``, ``BinaryOperator``
///
public enum BuiltinFunction: CaseIterable, Hashable, CustomStringConvertible {
    // Boolean
    /// Logical negation of a boolean value.
    ///
    case not
    /// Logical _AND_ for two or more arguments.
    ///
    case and
    /// Logical _OR_ for two or more arguments.
    ///
    case or

    /// Boolean conditional function.
    ///
    /// Arguments:
    /// - `condition`: a boolean value
    /// - `if_true`: a value used when the `condition` is _true_
    /// - `if_false`: a value used when the `condition` is _false_
    ///
    case `if`

    // Unary numeric
    /// Function for computing absolute (numeric) value.
    ///
    /// Expression: `abs(number)`
    ///
    case abs
    /// Function for computing rounded down, floor value.
    ///
    /// Expression: `floor(number)`
    ///
    case floor
    /// Function for computing rounded up, ceiling value.
    ///
    /// Expression: `ceiling(number)`
    ///
    case ceiling
    /// Function for computing rounded numeric value.
    ///
    /// Expression: `round(number)`
    ///
    case round
    case exp
    case sqrt
    
    // Variadic numeric
    /// Function for finding a minimum of one or more values.
    ///
    /// Use: `min(number, ...)` min out of of multiple values
    case min
    /// Function for finding a maximum of one or more values.
    ///
    /// Use: `max(number, ...)` max out of of multiple values
    case max
    /// Function for computing a sum of one or more values.
    ///
    /// Expression: `sum(number, ...)`
    case sum
    
    public enum Signature {
        case unaryNumeric
        case variadicNumeric
        case variadicNumericNonEmpty
        case variadicBoolean // Two or more
        case unaryBoolean
        case ternaryConditional // (bool, any, any) -> any

        public var returnType: ValueType {
            return switch self {
            case .unaryNumeric: ValueType.double
            case .variadicNumeric: ValueType.double
            case .variadicNumericNonEmpty: ValueType.double
            case .variadicBoolean: ValueType.bool
            case .unaryBoolean: ValueType.bool
            case .ternaryConditional: ValueType.double // TODO: Support `any`
            }
        }
        public var minimalArgumentCount: Int {
            return switch self {
            case .unaryNumeric: 1
            case .variadicNumeric: 0
            case .variadicNumericNonEmpty: 1
            case .variadicBoolean: 2
            case .unaryBoolean: 1
            case .ternaryConditional: 3
            }
        }
        /// Human readable description of the arguments.
        ///
        public var argumentString: String {
            return switch self {
            case .unaryNumeric: "x"
            case .variadicNumeric: "..."
            case .variadicNumericNonEmpty: "a, ..."
            case .variadicBoolean: "a, b, ..."
            case .unaryBoolean: "a"
            case .ternaryConditional: "condition, then, else"
            }
        }
        
        public func validate(_ types: [ValueType]) -> ArgumentValidationResult {
            switch self {
            case .unaryNumeric: // (numeric)
                guard types.count == 1 else { return .invalidNumberOfArguments }
                guard types[0].isConvertible(to: .numeric) else {
                    return .typeMismatch([0])
                }
            case .variadicNumeric: // (numeric, ...)
                var mismatch: [Int] = []
                for (index, type) in types.enumerated() {
                    if !type.isConvertible(to: .numeric) {
                        mismatch.append(index)
                    }
                }
                guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
            case .variadicNumericNonEmpty: // (numeric, ...)
                guard types.count >= 1 else { return .invalidNumberOfArguments }
                var mismatch: [Int] = []
                for (index, type) in types.enumerated() {
                    if !type.isConvertible(to: .numeric) {
                        mismatch.append(index)
                    }
                }
                guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
            case .variadicBoolean: // (bool, bool, ...)
                guard types.count >= 2 else { return .invalidNumberOfArguments }
                var mismatch: [Int] = []
                for (index, type) in types.enumerated() {
                    if !type.isConvertible(to: ValueType.bool) {
                        mismatch.append(index)
                    }
                }
                guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
            case .unaryBoolean: // (bool)
                guard types.count == 1 else { return .invalidNumberOfArguments }
                guard types[0].isConvertible(to: ValueType.bool) else {
                    return .typeMismatch([0])
                }
            case .ternaryConditional:
                guard types.count == 3 else { return .invalidNumberOfArguments }
                guard types[0].isConvertible(to: ValueType.bool) else {
                    return .typeMismatch([0])
                }
            }
            return .ok
        }
    }

    public var name: String {
        switch self {
        // Unary numeric
        case .abs: "abs"
        case .floor: "floor"
        case .ceiling: "ceiling"
        case .round: "round"
        case .exp: "exp"
        case .sqrt: "sqrt"
            
        // Unary logical
        case .not: "not"
        // Binary logical
        case .and: "and"
        case .or: "or"
            
        // Variadic numeric
        case .min: "min"
        case .max: "max"
        case .sum: "sum"
        case .if: "if"
        }
            
    }
    
    public var abstract: String {
        switch self {
        // Unary numeric
        case .abs: "Absolute value"
        case .floor: "Rounding downwards to the nearest integer"
        case .ceiling: "Rounding upwards to the nearest integer"
        case .round: "Rounding to the nearest integer"
        case .exp: "Natural exponent of x"
        case .sqrt: "Square root of x"
            
        // Unary logical
        case .not: "Negation of boolean value"
        // Binary logical
        case .and: "Logical AND of all the arguments – true if all arguments are true"
        case .or: "Logical OR of all the arguments – true if at least one is true"
            
        // Variadic numeric
        case .min: "Minimum value from a list of values"
        case .max: "Maximum value from a list of values"
        case .sum: "Sum of multiple values"
        case .if: "If the condition is true, return second argument, otherwise third"
        }
            
    }

    public var description: String { name }
    public var descriptionWithSignature: String { name + "(" + signature.argumentString + ")"}

    /// Get a function by name, where the name is case-insensitive.
    public init?(name: String) {
        switch name.lowercased() {
        // Unary numeric
        case "abs":     self = .abs
        case "floor":   self = .floor
        case "ceiling": self = .ceiling
        case "round":   self = .round
        case "exp":     self = .exp
        case "sqrt":    self = .sqrt

        // Unary logical
        case "not":     self = .not
        // Binary logical
        case "and":     self = .and
        case "or":      self = .or
                
        // Variadic numeric
        case "min":     self = .min
        case "max":     self = .max
        case "sum":     self = .sum
        case "if":      self = .if
        default:        return nil
        }
    }

    public var signature: Signature {
        switch self {
        // Unary numeric
        case .abs: .unaryNumeric
        case .floor: .unaryNumeric
        case .ceiling: .unaryNumeric
        case .round: .unaryNumeric
        case .exp: .unaryNumeric
        case .sqrt: .unaryNumeric

        // Unary logical
        case .not: .unaryBoolean
        // Binary logical
        case .and: .variadicBoolean
        case .or: .variadicBoolean
            
        // Variadic numeric
        case .min: .variadicNumericNonEmpty
        case .max: .variadicNumericNonEmpty
        case .sum: .variadicNumericNonEmpty
        case .if: .ternaryConditional
        }
    }
}

