//
//  NumericExpressionEvaluator.swift
//  
//
//  Created by Stefan Urbanek on 28/05/2022.
//

// TODO: Do not depend on HolonKit
enum SimpleExpressionError: Error {
    case unknownVariableReference(VariableReference)
    case unknownFunctionReference(BoundExpression.FunctionReference)
}

public class BuiltinVariable: Hashable {
    public static func == (lhs: BuiltinVariable, rhs: BuiltinVariable) -> Bool {
        return lhs.name == rhs.name && lhs.initialValue.isEqual(to: rhs.initialValue)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(initialValue)
    }
    
    let name: String
    let initialValue: any ValueProtocol
    
    init(name: String, value: any ValueProtocol) {
        self.name = name
        self.initialValue = value
    }
}

public enum VariableReference: Hashable {
    case object(ObjectID)
    case builtin(BuiltinVariable)
}
public typealias BoundExpression = ArithmeticExpression<VariableReference, String>


/// Object that evaluates numeric expressions.
///
/// The object is associated with list of numeric functions and variables that
/// will be used during each expression evaluation.
///
class NumericExpressionEvaluator {
    // TODO: This is rather "evaluation context"
    typealias FunctionReference = BoundExpression.FunctionReference

    var functions: [FunctionReference:FunctionProtocol] = [:]
    var variables: [VariableReference:any ValueProtocol]
    
    init(variables: [VariableReference:any ValueProtocol]=[:], functions: [String:FunctionProtocol]=[:]) {
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
