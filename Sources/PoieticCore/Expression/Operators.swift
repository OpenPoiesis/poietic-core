//
//  Operators.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/08/2026.
//
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Result of function argument validation.
///
public enum ArgumentValidationResult: Equatable {
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


public enum UnaryOperator: Equatable, CustomStringConvertible {
    case negate
    
    init?(symbol: String) {
        switch symbol {
        case "-": self = .negate
        default: return nil
        }
    }
    
    public var symbol: String {
        switch self {
        case .negate: "-"
        }
    }
    public var description: String { self.symbol }

    public func validate(_ types: [ValueType]) -> ArgumentValidationResult {
        switch self {
        case .negate:
            guard types.count == 1 else { return .invalidNumberOfArguments }
            guard types[0].isConvertible(to: .numeric) else {
                return .typeMismatch([0])
            }
        }
        return .ok
    }
    
    public var resultType: ValueType {
        // Note: currently the result does not depend on operators. We are keeping the signature though.
        switch self {
        case .negate: .double
        }
    }
}


public enum BinaryOperator: Equatable, CustomStringConvertible {
    // Comparison - equality
    case isEqual
    case notEqual
    
    // Comparison - ordinal
    case lessThan
    case greaterThan
    case lessOrEqual
    case greaterOrEqual

    // Arithmetic
    case add
    case subtract
    case multiply
    case divide
    case modulo
    case power
    
    public init?(symbol: String) {
        switch symbol {
        case "==": self = .isEqual
        case "!=": self = .notEqual

        case "<":  self = .lessThan
        case ">":  self = .greaterThan
        case "<=": self = .lessOrEqual
        case ">=": self = .greaterOrEqual

        case "+":  self = .add
        case "-":  self = .subtract
        case "*":  self = .multiply
        case "/":  self = .divide
        case "%":  self = .modulo
        case "^":  self = .power

        default:        return nil
        }
    }

    
    public var symbol: String {
        switch self {
        case .isEqual: "=="
        case .notEqual: "!="

        case .lessThan: "<"
        case .greaterThan: ">"
        case .lessOrEqual: "<="
        case .greaterOrEqual: ">="
            
        case .add: "+"
        case .subtract: "-"
        case .multiply: "*"
        case .divide: "/"
        case .modulo: "%"
        case .power: "^"
        }
    }
    
    public var description: String { self.symbol }

    public func validate(_ types: [ValueType]) -> ArgumentValidationResult {
        switch self {
        case .add, .subtract, .multiply, .divide,
                .modulo,.power,
                .lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual:
            guard types.count == 2 else { return .invalidNumberOfArguments }
            var mismatch: [Int] = []
            if !types[0].isConvertible(to: .numeric) {
                mismatch.append(0)
            }
            if !types[1].isConvertible(to: .numeric) {
                mismatch.append(1)
            }
            guard mismatch.isEmpty else { return .typeMismatch(mismatch) }
        case .isEqual, .notEqual:
            guard types.count == 2 else { return .invalidNumberOfArguments }
        }
        return .ok
    }
    
    public var resultType: ValueType {
        // Note: currently the result does not depend on operators. We are keeping the signature though.
        switch self {
        case .isEqual: .bool
        case .notEqual: .bool

        case .lessThan: .bool
        case .greaterThan: .bool
        case .lessOrEqual: .bool
        case .greaterOrEqual: .bool
            
        case .add: .double
        case .subtract: .double
        case .multiply: .double
        case .divide: .double
        case .modulo: .double
        case .power: .double
        }
    }
}
