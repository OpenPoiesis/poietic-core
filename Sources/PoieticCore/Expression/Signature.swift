//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 05/07/2023.
//


/// Object representing a function argument description.
///
/// - SeeAlso: ``Function``, ``Signature``
///
public struct FunctionArgument: Sendable {
    /// Name of the function argument.
    ///
    public let name: String
    
    /// Type of the function argument.
    ///
    public let type: VariableType
    
    /// Flag whether the argument is a constant.
    /// 
    public let isConstant: Bool
    
    /// Create a new function argument.
    ///
    /// - Parameters:
    ///     - name: Name of the argument.
    ///     - type: Argument type. Default is ``VariableType/any``.
    ///     - isConstant: Flag whether the function argument is a constant.
    ///
    public init(_ name: String, type: VariableType = .any, isConstant: Bool = false) {
        self.name = name
        self.type = type
        self.isConstant = isConstant
    }
}

/// Function signature.
///
/// An object that represents description of function's arguments.
///
/// Example of a signature for a string comparison function:
///
/// ```swift
/// let textComparisonSignature = Signature(
///     [
///         FunctionArgument(name: "left", type: .string),
///         FunctionArgument(name: "right", type: .string),
///     ],
///     returns: .bool
/// )
/// ```
///
/// A signature for a function `max(a, b, c, d, e)` where the arguments
/// can be any of the numeric types – _int_ or _double_:
///
/// ```swift
/// let maxNumberSignature = Signature(
///     variadic: FunctionArgument(name: "value",
///                                type: .union([.int, .double])),
///     returns: .double
/// )
/// ```
///
public final class Signature: CustomStringConvertible, Sendable {
    /// List of positional arguments.
    ///
    /// Positional arguments are the arguments at the beginning of the argument
    /// list.
    ///
    public let positional: [FunctionArgument]
    
    /// Type representing all variadic arguments of the function.
    ///
    /// If not provided, the function is not variadic.
    ///
    /// - SeeAlso: ``isVariadic``.
    ///
    public let variadic: FunctionArgument?
    
    /// Minimal number of arguments that are required.
    ///
    public var minimalArgumentCount: Int {
        if isVariadic {
            positional.count + 1
        }
        else {
            positional.count
        }
    }
    
    /// Flag whether the function is variadic.
    ///
    /// - SeeAlso: ``variadic``
    ///
    public var isVariadic: Bool { variadic != nil }
   
    /// Function return type.
    ///
    public let returnType: ValueType
    
    /// Convenience signature representing a numeric function with one argument.
    ///
    /// - Note: It is still recommended to create application-specific
    ///   signatures. This signature is provided for convenience.
    ///
    public static let NumericUnary = Signature(
        [
            FunctionArgument("value", type: .union([.int, .double]))
        ],
        returns: .double
    )
    /// Convenience signature representing a numeric function with many
    /// numeric arguments.
    ///
    /// - Note: It is still recommended to create application-specific
    ///   signatures. This signature is provided for convenience.
    ///
    public static let NumericVariadic = Signature(
        variadic: FunctionArgument("value", type: .union([.int, .double])),
        returns: .double
    )

    public var description: String {
        var argString = positional.map { "\($0.name):\($0.type)" }
            .joined(separator:",")
        if let variadic = self.variadic {
            argString += ",*\(variadic.name):\(variadic.type)..."
        }
        return "(\(argString)) -> \(returnType)"
    }
    
    public init(_ positional: [FunctionArgument] = [],
                variadic: FunctionArgument? = nil,
                returns returnType: ValueType) {
        self.positional = positional
        self.variadic = variadic
        self.returnType = returnType
    }

    /// Create a signature for all numeric arguments with given names.
    /// No variadic argument.
    ///
    convenience public init(numeric names: [String]) {
        let positional = names.map {
            FunctionArgument($0, type: .union([.int, .double]))
        }
        self.init(positional, returns: .double)
    }

    /// Create a signature for a variadic numeric argument with given name.
    /// No positional arguments.
    ///
    convenience public init(numericVariadic name: String) {
        let variadic = FunctionArgument(name, type: .union([.int, .double]))
        self.init(variadic: variadic, returns: .double)
    }

    /// Result of function validation.
    ///
    /// - SeeAlso: ``validate(_:)``
    ///
    public enum ValidationResult: Equatable {
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
    
    /// Validate the arguments against the signature.
    ///
    /// - Returns: ``ValidationResult`` which indicates whether the arguments
    ///   are as expected, whether the number of arguments is correct and
    ///   whether the argument types match signature expectations.
    ///
    public func validate(_ types: [ValueType] = []) -> ValidationResult {
        guard (isVariadic && (types.count >= positional.count + 1))
                || (!isVariadic && types.count == positional.count) else {
            return .invalidNumberOfArguments
        }
        
        let givenPositional = types.prefix(upTo: self.positional.count)
        let givenVariadic = types.suffix(from: self.positional.count)
        var mismatch: [Int] = []
        
        for (index, item) in zip(self.positional, givenPositional).enumerated() {
            let (expected, given) = item
            if !given.isConvertible(to: expected.type) {
                mismatch.append(index)
            }
        }
        
        if let variadic {
            for (index, given) in givenVariadic.enumerated() {
                if !given.isConvertible(to: variadic.type) {
                    mismatch.append(index + givenPositional.count)
                }
            }
        }
        
        if mismatch.isEmpty {
            return .ok
        }
        else {
            return .typeMismatch(mismatch)
        }
        
    }
}
