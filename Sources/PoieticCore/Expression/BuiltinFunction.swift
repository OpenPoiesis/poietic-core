//
//  BuildinFunctions2.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2026.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

public enum BuiltinFunction: Hashable, CustomStringConvertible {
    // Comparison - equality
    case isEqual
    case notEqual
    
    // Comparison - ordinal
    case lessThan
    case greaterThan
    case lessOrEqual
    case greaterOrEqual
    
    // Boolean
    case not
    case and
    case or
    case `if`

    // Unary numeric
    case negate
    case abs
    case floor
    case ceiling
    case round
    case exp
    
    // Binary numeric
    case add
    case subtract
    case multiply
    case divide
    case modulo
    case power
    
    // Variadic numeric
    case min
    case max
    case sum
    

    /// Result of function argument validation.
    ///
    public enum SignatureValidationResult: Equatable {
        /// Validation was successful.
        case ok
        
        /// Number of arguments does not match the required number of arguments.
        ///
        case invalidNumberOfArguments
        
        /// Argument types are of different type than expected. The associated
        /// value is a list of indices with arguments of which types do not
        /// match.
        ///
        case typeMismatch([Int])
    }

    public enum Signature {
        case unaryNumeric
        case binaryNumeric
        case variadicNumeric
        case variadicNumericNonEmpty
        case unaryBoolean
        case binaryBoolean
        case binaryComparable
        case binaryEquatable
        case ternaryConditional // (bool, any, any) -> any

        public var returnType: ValueType {
            return switch self {
            case .unaryNumeric: ValueType.double
            case .binaryNumeric: ValueType.double
            case .variadicNumeric: ValueType.double
            case .variadicNumericNonEmpty: ValueType.double
            case .unaryBoolean: ValueType.bool
            case .binaryBoolean: ValueType.bool
            case .binaryComparable: ValueType.bool
            case .binaryEquatable: ValueType.bool
            case .ternaryConditional: ValueType.double // TODO: Support `any`
            }
        }
        public var minimalArgumentCount: Int {
            return switch self {
            case .unaryNumeric: 1
            case .binaryNumeric: 2
            case .variadicNumeric: 0
            case .variadicNumericNonEmpty: 1
            case .unaryBoolean: 1
            case .binaryBoolean: 2
            case .binaryComparable: 2
            case .binaryEquatable: 2
            case .ternaryConditional: 3
            }
        }

        public func validate(_ types: [ValueType]) -> SignatureValidationResult {
            switch self {
            case .unaryNumeric: // (numeric)
                guard types.count == 1 else { return .invalidNumberOfArguments }
                guard types[0].isConvertible(to: .numeric) else {
                    return .typeMismatch([0])
                }
            case .binaryNumeric: // (numeric, numeric)
                guard types.count == 2 else { return .invalidNumberOfArguments }
                var mismatch: [Int] = []
                if !types[0].isConvertible(to: .numeric) {
                    mismatch.append(0)
                }
                if !types[1].isConvertible(to: .numeric) {
                    mismatch.append(1)
                }
                guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
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
            case .unaryBoolean: // (bool)
                guard types.count == 1 else { return .invalidNumberOfArguments }
                guard types[0].isConvertible(to: ValueType.bool) else {
                    return .typeMismatch([0])
                }
            case .binaryBoolean: // (bool, bool)
                guard types.count == 2 else { return .invalidNumberOfArguments }
                var mismatch: [Int] = []
                if !types[0].isConvertible(to: ValueType.bool) {
                    mismatch.append(0)
                }
                if !types[1].isConvertible(to: ValueType.bool) {
                    mismatch.append(1)
                }
                guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
            case .binaryComparable: // (numeric, numeric)
                guard types.count == 2 else { return .invalidNumberOfArguments }
                var mismatch: [Int] = []
                if !types[0].isConvertible(to: .numeric) {
                    mismatch.append(0)
                }
                if !types[1].isConvertible(to: .numeric) {
                    mismatch.append(1)
                }
                guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
            case .binaryEquatable: // (numeric, numeric )
                guard types.count == 2 else { return .invalidNumberOfArguments }
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
        // Equation
        case .isEqual: "__eq__"
        case .notEqual: "__neq__"
            
        // Comparison
        case .lessThan: "__lt__"
        case .greaterThan: "__gt__"
        case .lessOrEqual: "__le__"
        case .greaterOrEqual: "__ge__"
            
        // Unary numeric
        case .negate: "__neg__"
        case .abs: "abs"
        case .floor: "floor"
        case .ceiling: "ceiling"
        case .round: "round"
        case .exp: "exp"
            
        // Binary numeric
        case .add: "__add__"
        case .subtract: "__sub__"
        case .multiply: "__mul__"
        case .divide: "__div__"
        case .modulo: "__mod__"
        case .power: "__pow__"
            
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
    
    public var description: String { self.name }
    
    public init?(name: String) {
        let value: BuiltinFunction? = switch name {
        // Equation
        case "__eq__": .isEqual
        case "__neq__": .notEqual
                
        // Comparison
        case "__lt__": .lessThan
        case "__gt__": .greaterThan
        case "__le__": .lessOrEqual
        case "__ge__": .greaterOrEqual
                
        // Unary numeric
        case "__neg__": .negate
        case "abs": .abs
        case "floor": .floor
        case "ceiling": .ceiling
        case "round": .round
        case "exp": .exp
                
        // Binary numeric
        case "__add__": .add
        case "__sub__": .subtract
        case "__mul__": .multiply
        case "__div__": .divide
        case "__mod__": .modulo
        case "__pow__": .power
                
        // Unary logical
        case "not": .not
        // Binary logical
        case "and": .and
        case "or": .or
                
        // Variadic numeric
        case "min": .min
        case "max": .max
        case "sum": .sum
        case "if": .if
        default: nil
        }
        if let value {
            self = value
        }
        else {
            return nil
        }
    }

    public var signature: Signature {
        switch self {
        // Equation
        case .isEqual: .binaryEquatable
        case .notEqual: .binaryEquatable
            
        // Comparison
        case .lessThan: .binaryComparable
        case .greaterThan: .binaryComparable
        case .lessOrEqual: .binaryComparable
        case .greaterOrEqual: .binaryComparable
            
        // Unary numeric
        case .negate: .unaryNumeric
        case .abs: .unaryNumeric
        case .floor: .unaryNumeric
        case .ceiling: .unaryNumeric
        case .round: .unaryNumeric
        case .exp: .unaryNumeric
            
        // Binary numeric
        case .add: .binaryNumeric
        case .subtract: .binaryNumeric
        case .multiply: .binaryNumeric
        case .divide: .binaryNumeric
        case .modulo: .binaryNumeric
        case .power: .binaryNumeric
            
        // Unary logical
        case .not: .unaryBoolean
        // Binary logical
        case .and: .binaryBoolean
        case .or: .binaryBoolean
            
        // Variadic numeric
        case .min: .variadicNumericNonEmpty
        case .max: .variadicNumericNonEmpty
        case .sum: .variadicNumeric
        case .if: .ternaryConditional
        }
            
    }

    public func apply(_ arguments: [Variant]) throws (FunctionError) -> Variant {
        let result: Variant
        switch self {
            // Comparison - equality
        case .isEqual:
            guard arguments.count == 2 else { throw .invalidNumberOfArguments(arguments.count) }
            let (lhs, rhs) = (arguments[0], arguments[1])
            result = Variant(lhs == rhs)
        case .notEqual:
            guard arguments.count == 2 else { throw .invalidNumberOfArguments(arguments.count) }
            let (lhs, rhs) = (arguments[0], arguments[1])
            result = Variant(lhs != rhs)

        // Numeric comparison
        case .lessThan:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs < rhs)
        case .greaterThan:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs > rhs)
        case .lessOrEqual:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs <= rhs)
        case .greaterOrEqual:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs >= rhs)

        // Boolean
        case .not:
            let arg: Bool = try castArguments(arguments)
            result = Variant(!arg)
        case .and:
            let (lhs, rhs): (Bool, Bool) = try castArguments(arguments)
            result = Variant(lhs && rhs)
        case .or:
            let (lhs, rhs): (Bool, Bool) = try castArguments(arguments)
            result = Variant(lhs || rhs)
        case .`if`:
            let (condition, trueValue, falseValue): (Bool, Variant, Variant) = try castArguments(arguments)
            result = condition ? trueValue : falseValue
        // Unary numeric
        case .negate:
            let arg: Double = try castArguments(arguments)
            result = Variant(-arg)
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

        // Binary numeric
        case .add:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs + rhs)
        case .subtract:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs - rhs)
        case .multiply:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs * rhs)
        case .divide:
            // TODO: How to handle division by zero? We should not crash app because of user data
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs / rhs)
        case .modulo:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(lhs.truncatingRemainder(dividingBy: rhs))
        case .power:
            let (lhs, rhs): (Double, Double) = try castArguments(arguments)
            result = Variant(pow(lhs, rhs))
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
}

// Unary

func castArguments(_ arguments: [Variant]) throws (FunctionError) -> Double {
    guard arguments.count == 1 else { throw .invalidNumberOfArguments(arguments.count) }
    let first: Double

    do { first = try arguments[0].doubleValue() }
    catch { throw .invalidArgument(0, error) }

    return first
}
func castArguments(_ arguments: [Variant]) throws (FunctionError) -> Bool {
    guard arguments.count == 1 else { throw .invalidNumberOfArguments(arguments.count) }
    let first: Bool

    do { first = try arguments[0].boolValue() }
    catch { throw .invalidArgument(0, error) }

    return first
}
// Binary

func castArguments(_ arguments: [Variant]) throws (FunctionError) -> (Double, Double) {
    guard arguments.count == 2 else { throw .invalidNumberOfArguments(arguments.count) }
    let first: Double
    let second: Double

    do { first = try arguments[0].doubleValue() }
    catch { throw .invalidArgument(0, error) }

    do { second = try arguments[1].doubleValue() }
    catch { throw .invalidArgument(1, error) }

    return (first, second)
}

func castArguments(_ arguments: [Variant]) throws (FunctionError) -> (Bool, Bool) {
    guard arguments.count == 2 else { throw .invalidNumberOfArguments(arguments.count) }
    let first: Bool
    let second: Bool

    do { first = try arguments[0].boolValue() }
    catch { throw .invalidArgument(0, error) }

    do { second = try arguments[1].boolValue() }
    catch { throw .invalidArgument(1, error) }

    return (first, second)
}
// Ternary
func castArguments(_ arguments: [Variant]) throws (FunctionError) -> (Bool, Variant, Variant) {
    guard arguments.count == 3 else { throw .invalidNumberOfArguments(arguments.count) }
    let first: Bool

    do { first = try arguments[0].boolValue() }
    catch { throw .invalidArgument(0, error) }

    return (first, arguments[1], arguments[2])
}

// Variadic
func castArguments(_ arguments: [Variant]) throws (FunctionError) -> [Double] {
    var result: [Double] = Array(repeating: 0, count: arguments.count)
    for (i, arg) in arguments.enumerated() {
        do { result[i] = try arg.doubleValue() }
        catch { throw .invalidArgument(i, error) }
    }
    return result
}
