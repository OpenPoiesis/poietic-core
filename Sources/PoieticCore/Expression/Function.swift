//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/06/2022.
//


// TODO: This is an old design, might be a bit more complex than necessary, might need some simplification.
// NOTE: There were reasons for this design back then. Not sure if they still apply.

/// Error describing an issue with an argument passed to a function.
///
/// This structure is returned from validation of function arguments. See
/// `FunctionProtocol.validate()` for more information.
///
public enum FunctionError: Error, CustomStringConvertible {
    case invalidNumberOfArguments(Int, Int)
    case typeMismatch(Int, String)
    
    public var description: String {
        switch self {
        case .invalidNumberOfArguments(let actual, let expected):
            "Invalid number of arguments: \(actual), expected: \(expected)"
        case .typeMismatch(let number, let expected):
            "Invalid type of argument number \(number). Expected: \(expected)"
        }
    }
}

/// Protocol describing a function.
///
public protocol FunctionProtocol: Hashable, CustomStringConvertible {
    /// Name of the function
    var name: String { get }
    var signature: Signature { get }
    
    /// Applies the function to the arguments and returns the result. This
    /// function is guaranteed not to fail.
    ///
    /// - Note: Invalid arguments result in fatal error.
    ///
    /// - Throws: ``ValueError`` when the argument is not convertible to double.
    ///
    func apply(_ arguments: [Variant]) throws -> Variant
}

extension FunctionProtocol  {
    public var description: String {
        "\(name)(\(signature))"
    }
}

/// An object that represents a binary operator - a function of two
/// numeric arguments.
///
public class NumericBinaryFunction: FunctionProtocol {
    public typealias Implementation = (Double, Double) -> Double
    public let name: String
    public let implementation: Implementation
    public let signature: Signature
    
    public init(name: String, implementation: @escaping Implementation) {
        self.name = name
        self.implementation = implementation
        self.signature = Signature(
            [
                FunctionArgument("lhs", type: .numeric),
                FunctionArgument("rhs", type: .numeric),
            ],
            returns: .double
        )
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    /// Applies the function to the arguments and returns result.
    ///
    /// - Precondition: Arguments must be float convertible.
    ///
    /// - Throws: ``ValueError`` when the argument is not convertible to double.
    ///
    public func apply(_ arguments: [Variant]) throws -> Variant {
        guard arguments.count == 2 else {
            fatalError("Invalid number of arguments (\(arguments.count)) to a binary operator '\(name)'.")
        }

        let lhs = try arguments[0].doubleValue()
        let rhs = try arguments[1].doubleValue()

        let result = implementation(lhs, rhs)
        
        return Variant(result)
    }

    public static func == (lhs: NumericBinaryFunction, rhs: NumericBinaryFunction) -> Bool {
        return lhs === rhs
    }
}

/// An object that represents a unary operator - a function of one numeric
/// argument.
///
public class NumericUnaryFunction: FunctionProtocol {
    public typealias Implementation = (Double) -> Double
    
    public let name: String
    public let implementation: Implementation
    public let signature: Signature
    
    public init(name: String,
                argumentName: String = "value",
                implementation: @escaping Implementation) {
        self.name = name
        self.signature = Signature(
            [
                FunctionArgument(argumentName, type: .numeric)
            ],
            returns: .double
        )
        self.implementation = implementation
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    /// Applies the function to the arguments and returns result.
    ///
    /// - Precondition: Arguments must be float convertible.
    ///
    /// - Throws: ``ValueError`` when an argument is not convertible to double.
    ///
    public func apply(_ arguments: [Variant]) throws -> Variant {
        guard arguments.count == 1 else {
            fatalError("Invalid number of arguments (\(arguments.count) to a unary operator.")
        }

        let operand = try arguments[0].doubleValue()

        let result = implementation(operand)
        
        return Variant(result)
    }

    public static func == (lhs: NumericUnaryFunction, rhs: NumericUnaryFunction) -> Bool {
        return lhs === rhs
    }
}

/// An object that represents a generic function of zero or multiple numeric
/// arguments and returning a numeric value.
///
public class NumericFunction: FunctionProtocol {
    public typealias Implementation = ([Double]) -> Double
    
    public let name: String
    public let implementation: Implementation
    public let signature: Signature
    
    public init(name: String,
                signature: Signature,
                implementation: @escaping Implementation) {
        self.name = name
        self.signature = signature
        self.implementation = implementation
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }


    /// Applies the function to the arguments and returns result.
    ///
    /// - Precondition: Arguments must be float convertible.
    ///
    /// - Throws: ``ValueError`` when any of the arguments is not convertible to double.
    ///
    public func apply(_ arguments: [Variant]) throws -> Variant {
        let floatArguments = try arguments.map { try $0.doubleValue() }

        let result = implementation(floatArguments)
        
        return Variant(result)
    }

    public static func == (lhs: NumericFunction, rhs: NumericFunction) -> Bool {
        return lhs === rhs
    }
}

