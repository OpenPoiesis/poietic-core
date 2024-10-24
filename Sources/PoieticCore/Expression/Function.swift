//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/06/2022.
//


/// Class representing a function used in arithmetic expression evaluation.
///
public class Function: CustomStringConvertible {
    /// Type of the function callable body closure.
    ///
    /// The body takes a list of variants and returns a variant.
    ///
    public typealias Body = ([Variant]) throws -> Variant
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
    
    /// Create a function that takes variable number of numeric values and
    /// returns a numeric value.
    ///
    public static func NumericVariadic(_ name: String,
                                       body: @escaping ([Double]) -> Double) -> Function {
        Function(
            name: name,
            signature: Signature(numericVariadic: "value"),
            body: { arguments in
                let floatArguments = try! arguments.map { try $0.doubleValue() }
                let result = body(floatArguments)
                return Variant(result)
            }
        )
    }

    /// Create a variadic function that takes a list of boolean arguments and returns
    /// a boolean.
    ///
    public static func BooleanVariadic(_ name: String,
                                       body: @escaping ([Bool]) -> Bool) -> Function {
        Function(
            name: name,
            signature: Signature(
                variadic: FunctionArgument("value", type: .bool),
                returns: .bool
            ),
            body: { arguments in
                let floatArguments = try! arguments.map { try $0.boolValue() }
                let result = body(floatArguments)
                return Variant(result)
            }
        )
    }
    
    
    /// Create a function that takes two numeric values (int or double) and returns
    /// a double value.
    ///
    public static func NumericBinary(_ name: String,
                                     leftArgument: String = "lhs",
                                     rightArgument: String = "rhs",
                              body: @escaping (Double, Double) -> Double) -> Function {
        Function(
            name: name,
            signature: Signature(
                [
                    FunctionArgument(leftArgument, type: .numeric),
                    FunctionArgument(rightArgument, type: .numeric),
                ],
                returns: .double
            ),
            body: { arguments in
                guard arguments.count == 2 else {
                    fatalError("Invalid number of arguments (\(arguments.count)) to a binary numeric function '\(name)'.")
                }

                let lhs = try! arguments[0].doubleValue()
                let rhs = try! arguments[1].doubleValue()

                let result = body(lhs, rhs)
                
                return Variant(result)
            }
        )
    }
    
    /// Create a function that takes a numeric values (int or double) and returns
    /// a double value.
    ///
    public static func NumericUnary(_ name: String,
                                    argumentName: String = "value",
                                    body: @escaping (Double) -> Double) -> Function {
        Function(
            name: name,
            signature: Signature(
                [
                    FunctionArgument(argumentName, type: .numeric),
                ],
                returns: .double
            ),
            body: { arguments in
                guard arguments.count == 1 else {
                    fatalError("Invalid number of arguments (\(arguments.count)) to unary numeric function '\(name)'.")
                }

                let argument = try! arguments[0].doubleValue()
                let result = body(argument)
                
                return Variant(result)
            }
        )
    }

    /// Create a comparison function that takes two values of any type and returns a
    /// boolean.
    ///
    public static func Comparison(_ name: String,
                          body: @escaping (Variant, Variant) throws -> Bool) -> Function {
        Function(
            name: name,
            signature: Signature(
                [
                    FunctionArgument("lhs", type: .any),
                    FunctionArgument("rhs", type: .any),
                ],
                returns: .bool
            ),
            body: { arguments in
                guard arguments.count == 2 else {
                    fatalError("Invalid number of arguments (\(arguments.count)) to comparison operator '\(name)'.")
                }

                let result = try! body(arguments[0], arguments[1])
                
                return Variant(result)
            }
        )
    }

    public var description: String {
        "\(name)(\(signature))"
    }
}
