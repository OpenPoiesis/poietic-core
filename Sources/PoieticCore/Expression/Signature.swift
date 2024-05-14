//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 05/07/2023.
//


/// Object representing a function argument description.
///
public struct FunctionArgument {
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
    ///     - type: Argument type. Default is ``ArgumentType/any``.
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
/// Example:
///
/// ```swift
///
/// // A signature for a function `compare(left, right)`
///
/// let textComparisonSignature = Signature(
///     [
///         FunctionArgument(name: "left",
///                          type: .string),
///         FunctionArgument(name: "right",
///                          type: .string),
///     ]
/// )
///
/// // A signature for a function `max(a, b, c, d, e)`
///
/// let maxNumberSignature = Signature(
///     variadic: FunctionArgument(name: "left",
///                                type: .union([.int, .double]))
/// )
/// ```
///
public class Signature: CustomStringConvertible {
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
    public let variadic: FunctionArgument?
    
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
    public var isVariadic: Bool { variadic != nil }
   
    public var returnType: ValueType
    
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

    public enum ValidationResult: Equatable {
        case ok
        case invalidNumberOfArguments
        case typeMismatch([Int])
    }
    /// Return list of indices of values that do not match required type.
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
