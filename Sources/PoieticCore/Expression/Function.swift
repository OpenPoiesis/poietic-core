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
public struct FunctionArgumentError {
    // TODO: Use direct function reference instead of a name
    
    /// Name of the function
    public let function: String
    
    /// Detailed information about the error.
    public let message: String
    
    /// Index of the argument that is causing the error or nil if there is
    /// an issue that can not be associated with a concrete argument.
    public let argument: Int?
    
    /// Creates a new function argument error.
    ///
    /// - Parameters:
    ///     - function: Name of a function that claims the validation error
    ///     - message: detailed information about the error
    ///     - argument: index of the argument that caused the error
    ///
    public init(function: String, message: String, argument: Int?=nil) {
        self.function = function
        self.message = message
        self.argument = argument
    }
}

/// Protocol describing a function.
///
public protocol FunctionProtocol {
    /// Name of the function
    var name: String { get }
    
    /// Validate arguments that are expected to be passed to the function.
    /// Returns a list of errors if there are issues with the arguments.
    /// The list is empty if there are no issues.
    ///
    func validate(_ arguments: [any ValueProtocol]) -> [FunctionArgumentError]
    
    /// Applies the function to the arguments and returns the result. This
    /// function is guaranteed not to fail.
    ///
    /// - Note: Invalid arguments result in fatal error.
    ///
    func apply(_ arguments: [any ValueProtocol]) -> any ValueProtocol
}


/// Type representing a concrete function that evaluates the arguments of
/// `Value` type and returns a value.
///
public typealias FunctionImplementation = ([any ValueProtocol]) -> any ValueProtocol

/// An object that represents a binary operator - a function of two
/// numeric arguments.
///
public class NumericBinaryOperator: FunctionProtocol {
    public typealias Implementation = (Double, Double) -> Double
    public let name: String
    public let implementation: Implementation
    
    init(name: String, implementation: @escaping Implementation) {
        self.name = name
        self.implementation = implementation
    }
    
    /// Returns a list of indices of arguments that have mismatched types
    public func validate(_ arguments: [any ValueProtocol]) -> [FunctionArgumentError] {
        var errors: [FunctionArgumentError] = []
        
        if arguments.count != 2 {
            errors.append(
                FunctionArgumentError(function: name,
                              message: "Invalid number of arguments (\(arguments.count) for binary operator. Expected exactly 2.")
            )
        }
        
        for (i, arg) in arguments.enumerated() {
            if !arg.valueType.isNumeric {
                errors.append(
                    FunctionArgumentError(function: name,
                                  message: "Invalid argument type. Argument number \(i) is \(arg.valueType) expected is float or int")
                )
            }
        }
        
        return errors
    }
    
    /// Applies the function to the arguments and returns result.
    ///
    /// - Precondition: Arguments must be float convertible.
    ///
    public func apply(_ arguments: [any ValueProtocol] ) -> any ValueProtocol {
        guard arguments.count == 2 else {
            fatalError("Invalid number of arguments (\(arguments.count) to a binary operator.")
        }

        let lhs = arguments[0].doubleValue()!
        let rhs = arguments[1].doubleValue()!

        let result = implementation(lhs, rhs)
        
        return result
    }

    public static func == (lhs: NumericBinaryOperator, rhs: NumericBinaryOperator) -> Bool {
        return lhs === rhs
    }
}

/// An object that represents a unary operator - a function of one numeric
/// argument.
///
public class NumericUnaryOperator: FunctionProtocol {
    public typealias Implementation = (Double) -> Double
    
    public let name: String
    public let implementation: Implementation
    
    public init(name: String, implementation: @escaping Implementation) {
        self.name = name
        self.implementation = implementation
    }
    
    /// Returns a list of indices of arguments that have mismatched types
    public func validate(_ arguments: [any ValueProtocol]) -> [FunctionArgumentError] {
        var errors: [FunctionArgumentError] = []
        
        if arguments.count != 1 {
            errors.append(
                FunctionArgumentError(function: name,
                              message: "Invalid number of arguments (\(arguments.count) for unary operator. Expected exactly 1.")
            )
        }
        let arg = arguments[0]
        
        if !arg.valueType.isNumeric {
            errors.append(
                FunctionArgumentError(function: name,
                              message: "Invalid argument type. Argument is \(arg.valueType) expected is float or int")
            )
        }
        
        return errors
    }
    
    /// Applies the function to the arguments and returns result.
    ///
    /// - Precondition: Arguments must be float convertible.
    ///
    public func apply(_ arguments: [any ValueProtocol] ) -> any ValueProtocol {
        guard arguments.count == 1 else {
            fatalError("Invalid number of arguments (\(arguments.count) to a unary operator.")
        }

        let operand = arguments[0].doubleValue()!

        let result = implementation(operand)
        
        return result
    }

    public static func == (lhs: NumericUnaryOperator, rhs: NumericUnaryOperator) -> Bool {
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
    public let signature: [String]
    public let isVariadic: Bool
    
    public init(name: String, signature: [String]=[], isVariadic: Bool=false,
         implementation: @escaping Implementation) {
        self.name = name
        self.implementation = implementation
        self.signature = signature
        self.isVariadic = isVariadic
    }
    
    /// Returns a list of indices of arguments that have mismatched types
    public func validate(_ arguments: [any ValueProtocol]) -> [FunctionArgumentError] {
        var errors: [FunctionArgumentError] = []
        
        // FIXME: Use new flag "required" - whether at least one argument is required
        if isVariadic {
            if signature.count == 0 && arguments.count == 0 {
                errors.append(
                    FunctionArgumentError(function: name,
                                  message: "Variadic function expects at least one argument")
                )
            }
        }
        else {
            if arguments.count != signature.count {
                errors.append(
                    FunctionArgumentError(function: name,
                                  message: "Expected \(signature.count) arguments, provided (\(arguments.count).")
                )
            }
        }
        
        for (i, arg) in arguments.enumerated() {
            if !arg.valueType.isNumeric {
                errors.append(
                    FunctionArgumentError(function: name,
                                  message: "Invalid argument type. Argument number \(i) is \(arg.valueType) expected is float or int")
                )
            }
        }
        
        return errors
    }

    /// Applies the function to the arguments and returns result.
    ///
    /// - Precondition: Arguments must be float convertible.
    ///
    public func apply(_ arguments: [any ValueProtocol]) -> any ValueProtocol {
        let floatArguments = arguments.map { $0.doubleValue()! }

        let result = implementation(floatArguments)
        
        return result
    }

    public static func == (lhs: NumericFunction, rhs: NumericFunction) -> Bool {
        return lhs === rhs
    }
}

