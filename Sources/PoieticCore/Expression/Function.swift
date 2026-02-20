//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/06/2022.
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
    
    /// Create a new function argument.
    ///
    /// - Parameters:
    ///     - name: Name of the argument.
    ///     - type: Argument type. Default is ``VariableType/any``.
    ///     - isConstant: Flag whether the function argument is a constant.
    ///
    public init(_ name: String, type: VariableType = .any) {
        self.name = name
        self.type = type
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
    public static let NumericBinaryOperator = Signature(
        [
            FunctionArgument("left", type: .union([.int, .double])),
            FunctionArgument("right", type: .union([.int, .double]))
        ],
        returns: .double
    )
    public static let EquatableOperator = Signature(
        [
            FunctionArgument("left", type: .any),
            FunctionArgument("right", type: .any)
        ],
        returns: .bool
    )
    public static let ComparisonOperator = Signature(
        [
            FunctionArgument("left", type: .union([.int, .double])),
            FunctionArgument("right", type: .union([.int, .double]))
        ],
        returns: .bool
    )
    public static let LogicalBinaryOperator = Signature(
        [
            FunctionArgument("left", type: .union([.bool])),
            FunctionArgument("right", type: .union([.bool]))
        ],
        returns: .bool
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

/// Error thrown when a function body is called.
///
/// - SeeAlso: ``Function/apply``
///
public enum FunctionError: Error {
    case invalidArgument(Int, ValueError)
    case invalidNumberOfArguments(Int)
    case notComparableTypes(ValueType, ValueType)
}

/// Class representing a function used in arithmetic expression evaluation.
///
public class Function: CustomStringConvertible {
    /// Type of the function callable body closure.
    ///
    /// The body takes a list of variants and returns a variant.
    ///
    public typealias Body = ([Variant]) throws (FunctionError) -> Variant

    /// Name of the function.
    ///
    /// - SeeAlso: ``ArithmeticExpression/function(_:_:)``
    ///
    public let name: String
    
    /// Signature of the function.
    ///
    /// Signature describes function's arguments, their types and the return type. It is used
    /// for argument validation.
    ///
    public let signature: Signature
    
    /// Closure representing the function body.
    ///
    /// Use the closure:
    ///
    /// ```swift
    /// let function: Function   // Assume we have this
    /// let arguments: [Variant]
    ///
    /// result = function.apply(arguments)
    /// ```
    ///
    public let apply: Body

    /// Create a new function with given name and signature.
    ///
    /// - Parameters:
    ///  - name: Name of the function
    ///  - signature: Signature of the function - types of arguments and return value
    ///  - body: Function body block
    ///
    /// Example:
    ///
    /// ```swift
    ///  let binaryNumericSignature = Signature(
    ///        [
    ///            FunctionArgument("left", type: .numeric),
    ///            FunctionArgument("right", type: .numeric),
    ///        ],
    ///        returns: .double
    ///    )
    ///
    ///  let add = Function(
    ///    name: "add",
    ///    signature: binaryNumericSignature,
    ///    body: { arguments in
    ///        let left = try! arguments[0].doubleValue()
    ///        let left = try! arguments[1].doubleValue()
    ///
    ///        return Variant(lhs + rhs)
    ///    }
    /// )
    /// ```
    ///
    /// - SeeAlso: ``Signature``
    ///
    public init(name: String, signature: Signature, body: @escaping Body) {
        self.name = name
        self.signature = signature
        self.apply = body
    }
    
    
    /// Create a function that takes variable number of numeric values and
    /// returns a numeric value.
    ///
    public convenience init(numericVariadic name: String, body: @escaping ([Double]) -> Double) {
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count >= 1 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }

            let numericArguments = try doubleValues(args)
            let result = body(numericArguments)
            return Variant(result)
        }
        
        self.init(name: name,
                  signature: Signature(numericVariadic: "value"),
                  body: wrappedBody)
    }

    /// Create a variadic function that takes a list of boolean arguments and returns
    /// a boolean.
    ///
    public convenience init(booleanVariadic name: String, body: @escaping ([Bool]) -> Bool) {
        let wrappedBody: Body = { args in
            let numericArguments = try boolValues(args)
            let result = body(numericArguments)
            return Variant(result)
        }
        
        self.init(
            name: name,
            signature: Signature(
                variadic: FunctionArgument("value", type: .bool),
                returns: .bool
            ),
            body: wrappedBody
        )
    }
    
    /// Create a function that takes two numeric values (int or double) and returns
    /// a double value.
    ///
    public convenience init(numericBinary name: String,
                            leftName: String = "lhs",
                            rightName: String = "rhs",
                            body: @escaping (Double, Double) -> Double) {
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count == 2 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }
            
            let numericArguments = try doubleValues(args)
            let result = body(numericArguments[0], numericArguments[1])
            return Variant(result)
        }
        
        self.init(
            name: name,
            signature: Signature(
                [
                    FunctionArgument(leftName, type: .numeric),
                    FunctionArgument(rightName, type: .numeric),
                ],
                returns: .double
            ),
            body: wrappedBody
        )
    }
    
    /// Create a function that takes a numeric values (int or double) and returns
    /// a double value.
    ///
    public convenience init(numericUnary name: String,
                            argumentName: String = "value",
                            body: @escaping (Double) -> Double) {
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count == 1 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }
            
            let numericArguments = try doubleValues(args)
            let result = body(numericArguments[0])
            return Variant(result)
        }

        self.init(
            name: name,
            signature: Signature(
                [FunctionArgument(argumentName, type: .numeric)],
                returns: .double
            ),
            body: wrappedBody
        )
    }

    /// Create a comparison function that takes two values of any type and returns a
    /// boolean.
    ///
    public convenience init(comparison name: String,
                            body: @escaping (Variant, Variant) throws (FunctionError) -> Bool) {
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count == 2 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }
            let result = try body(args[0], args[1])
            return Variant(result)
        }

        self.init(
            name: name,
            signature: Signature(
                [
                    FunctionArgument("lhs", type: .any),
                    FunctionArgument("rhs", type: .any),
                ],
                returns: .bool
            ),
            body: wrappedBody
        )
    }

    public var description: String {
        "\(name)(\(signature))"
    }
}

func boolValues(_ args: [Variant]) throws (FunctionError) -> [Bool] {
    var values: [Bool] = []
    
    for (index, arg) in args.enumerated() {
        do {
            values.append(try arg.boolValue())
        }
        catch {
            throw .invalidArgument(index, error)
        }
    }
    return values
}

func doubleValues(_ args: [Variant]) throws (FunctionError) -> [Double] {
    var values: [Double] = []
    
    for (index, arg) in args.enumerated() {
        do {
            values.append(try arg.doubleValue())
        }
        catch {
            throw .invalidArgument(index, error)
        }
    }
    return values
}
