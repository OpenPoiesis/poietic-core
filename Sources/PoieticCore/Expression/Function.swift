//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/06/2022.
//


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
    /// The name in a function call used in ``ArithmeticExpression`` refers to
    /// a function with corresponding name.
    ///
    public let name: String
    
    /// Signature of the function - list of arguments, their types and a type
    /// of the return value.
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
    
    public static func boolValues(_ args: [Variant]) throws (FunctionError) -> [Bool] {
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

    public static func doubleValues(_ args: [Variant]) throws (FunctionError) -> [Double] {
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
    
    /// Create a function that takes variable number of numeric values and
    /// returns a numeric value.
    ///
    public static func NumericVariadic(_ name: String, body: @escaping ([Double]) -> Double) -> Function {
        let wrappedBody: Body = { args in
            let numericArguments = try doubleValues(args)
            let result = body(numericArguments)
            return Variant(result)
        }
        
        return Function(name: name,
                        signature: Signature(numericVariadic: "value"),
                        body: wrappedBody)
    }

    /// Create a variadic function that takes a list of boolean arguments and returns
    /// a boolean.
    ///
    public static func BooleanVariadic(_ name: String, body: @escaping ([Bool]) -> Bool) -> Function {
        let wrappedBody: Body = { args in
            let numericArguments = try boolValues(args)
            let result = body(numericArguments)
            return Variant(result)
        }
        
        return Function(
                name: name,
                signature: Signature(
                    variadic: FunctionArgument("value", type: .bool),
                    returns: .bool
                ),
                body: wrappedBody)
    }
    
    /// Create a function that takes two numeric values (int or double) and returns
    /// a double value.
    ///
    public static func NumericBinary(_ name: String,
                                     leftName: String = "lhs",
                                     rightName: String = "rhs",
                                     body: @escaping (Double, Double) -> Double) -> Function {
        
        
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count == 2 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }
            
            let numericArguments = try doubleValues(args)
            let result = body(numericArguments[0], numericArguments[1])
            return Variant(result)
        }
        
        return Function(name: name,
                        signature: Signature(
                            [
                                FunctionArgument(leftName, type: .numeric),
                                FunctionArgument(rightName, type: .numeric),
                            ],
                            returns: .double
                        ),
                        body: wrappedBody)
    }
    
    /// Create a function that takes a numeric values (int or double) and returns
    /// a double value.
    ///
    public static func NumericUnary(_ name: String,
                                    argumentName: String = "value",
                                    body: @escaping (Double) -> Double) -> Function {
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count == 1 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }
            
            let numericArguments = try doubleValues(args)
            let result = body(numericArguments[0])
            return Variant(result)
        }

        return Function(name: name,
                        signature: Signature(
                            [FunctionArgument(argumentName, type: .numeric)],
                            returns: .double
                        ),
                        body: wrappedBody )
    }

    /// Create a comparison function that takes two values of any type and returns a
    /// boolean.
    ///
    public static func Comparison(_ name: String,
                          body: @escaping (Variant, Variant) throws (FunctionError) -> Bool) -> Function {
        let wrappedBody: Body = { args throws (FunctionError) in
            guard args.count == 2 else {
                throw FunctionError.invalidNumberOfArguments(args.count)
            }
            let result = try body(args[0], args[1])
            return Variant(result)
        }


        return Function(name: name,
                        signature: Signature(
                            [
                                FunctionArgument("lhs", type: .any),
                                FunctionArgument("rhs", type: .any),
                            ],
                            returns: .bool
                        ),
                        body: wrappedBody)
    }

    public var description: String {
        "\(name)(\(signature))"
    }
}
