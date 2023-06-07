//
//  NumericExpressionEvaluator.swift
//  
//
//  Created by Stefan Urbanek on 28/05/2022.
//

// TODO: Needs attention, a bit older design.

enum SimpleExpressionError: Error {
    case unknownVariableReference(BoundVariableReference)
    case unknownFunctionReference(BoundExpression.FunctionReference)
}

/// Object representing a built-in variable.
///
/// Each instance of this type represents a variable within a domain model. It
/// provides information about the variable such as description or expected
/// type.
///
/// Example built-in variables: `time`, `time_delta`, `previous_value`, …
///
/// The instance does not represent the value of the variable.
///
/// There should be only one instance of the variable per concept within the
/// domain model. Therefore instances of built-in variables can be compared
/// with identity comparison operator (`===`).
///
public class BuiltinVariable: Hashable {
    public let name: String
    public let initialValue: (any ValueProtocol)?
    public let description: String?
    
    public init(name: String,
         value: (any ValueProtocol)? = nil,
         description: String?) {
        self.name = name
        self.initialValue = value
        self.description = description
    }
    
    public static func ==(lhs: BuiltinVariable, rhs: BuiltinVariable) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

public enum BoundVariableReference: Hashable {
    
    case object(ObjectID)
    case builtin(BuiltinVariable)
    
    public static func ==(lhs: BoundVariableReference, rhs: BoundVariableReference) -> Bool {
        switch (lhs, rhs) {
        case let (.object(left), .object(right)): return left == right
        case let (.builtin(left), .builtin(right)): return left == right
        default: return false
        }
    }
}


public typealias BoundExpression = ArithmeticExpression<BoundVariableReference, String>

extension ArithmeticExpression where V == String, F == String {
    /// Bind an expression to a compiled model. Return a bound expression.
    ///
    /// Bound expression is an expression where the variable references are
    /// resolved to match their respective nodes.
    ///
    public func bind(variables: [String:BoundVariableReference]) -> BoundExpression {
        switch self {
        case let .value(value): return .value(value)
        case let .binary(op, lhs, rhs):
            return .binary(op, lhs.bind(variables: variables),
                           rhs.bind(variables: variables))
        case let .unary(op, operand):
            return .unary(op, operand.bind(variables: variables))
        case let .function(name, arguments):
            let boundArgs = arguments.map { $0.bind(variables: variables) }
            return .function(name, boundArgs)
        case let .variable(name):
            if let ref = variables[name]{
                return .variable(ref)
            }
            else {
                // TODO: Raise an error here
                fatalError("Unknown variable name: '\(name)'")
            }
        case .null: return .null
        }
    }
}

/// Object that evaluates numeric expressions.
///
/// The object is associated with list of numeric functions and variables that
/// will be used during each expression evaluation.
///
class NumericExpressionEvaluator {
    // TODO: This is rather "evaluation context"
    typealias FunctionReference = BoundExpression.FunctionReference

    var functions: [FunctionReference:FunctionProtocol] = [:]
    var variables: [BoundVariableReference:any ValueProtocol]
    
    init(variables: [BoundVariableReference:any ValueProtocol]=[:], functions: [String:FunctionProtocol]=[:]) {
        self.variables = variables
        self.functions = functions
    }
    
    /// Evaluates an expression using object's functions and variables. Returns
    /// the evaluation result.
    ///
    /// - Throws: The function throws an error when it encounters a variable
    ///   or a function with unknown name
    func evaluate(_ expression: BoundExpression) throws -> (any ValueProtocol)? {
        switch expression {
        case let .value(value): return value
        case let .binary(op, lhs, rhs):
            return try apply(op, arguments: [try evaluate(lhs), try evaluate(rhs)])
        case let .unary(op, operand):
            return try apply(op, arguments: [try evaluate(operand)])
        case let .function(name, arguments):
            let evaluatedArgs = try arguments.map { try evaluate($0) }
            return try apply(name, arguments: evaluatedArgs)
        case let .variable(name):
            if let value = variables[name] {
                return value
            }
            else {
                throw SimpleExpressionError.unknownVariableReference(name)
            }
        case .null: return nil
        }
    }
    
    /// Applies the function to the arguments and returns the result.
    ///
    /// - Throws: If the function with given name does not exist, it throws
    ///   an error.
    ///
    func apply(_ functionReference: FunctionReference, arguments: [(any ValueProtocol)?]) throws -> any ValueProtocol {
        guard let function = functions[functionReference] else {
            throw SimpleExpressionError.unknownFunctionReference(functionReference)
        }
        // FIXME: Handle optionals, the following is workaround
        let args: [any ValueProtocol] = arguments.map { $0! }
        return function.apply(args)
    }
}
