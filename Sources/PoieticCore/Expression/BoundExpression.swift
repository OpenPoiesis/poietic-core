//
//  NumericExpressionEvaluator.swift
//  
//
//  Created by Stefan Urbanek on 28/05/2022.
//

// TODO: Needs attention, a bit older design.

public enum ExpressionError: Error {
    case unknownVariable(String)
    case unknownFunction(String)
    case functionError(FunctionError)
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
    public let initialValue: ForeignValue?
    public let description: String?

    // TODO: Make customizable
    public let valueType: AtomType = .double
    
    public init(name: String,
                value: ForeignValue? = nil,
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

public enum BoundVariableReference: Hashable, CustomStringConvertible {
    
    case object(ObjectID)
    case builtin(BuiltinVariable)
    
    public static func ==(lhs: BoundVariableReference, rhs: BoundVariableReference) -> Bool {
        switch (lhs, rhs) {
        case let (.object(left), .object(right)): return left == right
        case let (.builtin(left), .builtin(right)): return left === right
        default: return false
        }
    }
    
    public var valueType: AtomType {
        switch self {
        case .object: AtomType.double
        case .builtin(let variable): variable.valueType
        }
    }
    
    public var description: String {
        switch self {
        case .object(let id): "object(\(id))"
        case .builtin(let variable): "builtin(\(variable.name))"
        }
    }
}


// TODO: Rename to Bound Numeric Expression
public typealias BoundExpression = ArithmeticExpression<ForeignValue,
                                                        BoundVariableReference,
                                                        any FunctionProtocol>

extension BoundExpression {
    public var valueType: AtomType {
        let type = switch self {
        case let .value(value): value.valueType
        case let .variable(ref): ref.valueType
        case let .binary(fun, _, _): fun.signature.returnType
        case let .unary(fun, _): fun.signature.returnType
        case let .function(fun, _): fun.signature.returnType
        }
        
        guard let type else {
            fatalError("Bound expression \(self) has an unknown type. Hint: Something is broken in the binding process and/or built-in function definitions")
        }
        
        return type
    }
}

/// Bind an expression to concrete variable references.
///
/// - Parameters:
///     - expression: Unbound arithmetic expression, where the function and
///       variable references are strings.
///     - variables: Dictionary of variables where the keys are variable names
///       and the values are (bound) references to the variables.
///     - functions: Dictionary of functions and operators where the keys are
///       function names and the values are objects representing functions.
///       See the list below of special function names that represent operators.
///
/// The operators are functions with special names. The following list contains
/// the names of the operators:
///
/// - `__add__` – binary addition operator `+`
/// - `__sub__` – binary subtraction operator `-`
/// - `__mul__` – binary multiplication operator `*`
/// - `__div__` – binary division operator `/`
/// - `__mod__` – binary modulo operator `%`
/// - `__neg__` – unary negation operator `-`
///
/// - Note: The operator names are similar to the operator method names in
///   Python.
///
/// - Returns: ``BoundExpression`` where variables and functions are resolved.
/// - Throws: ``ExpressionError`` when a variable or a function is not known
///  or when the function arguments do not match the function's requirements.
///
public func bindExpression(_ expression: UnboundExpression,
                           variables: [String:BoundVariableReference],
                           functions: [String:any FunctionProtocol]) throws -> BoundExpression {
    
    switch expression {
    case let .value(value):
        return .value(value)

    case let .unary(op, operand):
        let funcName: String = switch op {
        case "-": "__neg__"
        default: fatalError("Unknown unary operator: '\(op)'. Hint: check the expression parser.")
        }

        guard let function = functions[funcName] else {
            fatalError("No function '\(funcName)' for unary operator: '\(op)'. Hint: Make sure it is defined in the builtin function list.")
        }

        let boundOperand = try bindExpression(operand,
                                              variables: variables,
                                              functions: functions)
        
        let result = function.signature.validate([boundOperand.valueType])
        switch result {
        case .invalidNumberOfArguments:
            throw FunctionError.invalidNumberOfArguments(1,
                                                         function.signature.minimalArgumentCount)
        case .typeMismatch(_):
            throw FunctionError.typeMismatch(1, "int or double")
        default:
            return .unary(function, boundOperand)
        }
        
        
    case let .binary(op, lhs, rhs):
        let funcName: String = switch op {
        case "+": "__add__"
        case "-": "__sub__"
        case "*": "__mul__"
        case "/": "__div__"
        case "%": "__mod__"
        default: fatalError("Unknown binary operator: '\(op)'. Internal hint: check the expression parser.")
        }
        
        guard let function = functions[funcName] else {
            fatalError("No function '\(funcName)' for binary operator: '\(op)'. Internal hint: Make sure it is defined in the builtin function list.")
        }

        let lBound = try bindExpression(lhs, variables: variables, functions: functions)
        let rBound = try bindExpression(rhs, variables: variables, functions: functions)

        let result = function.signature.validate([lBound.valueType, rBound.valueType])
        switch result {
        case .invalidNumberOfArguments:
            throw FunctionError.invalidNumberOfArguments(2,
                                                         function.signature.minimalArgumentCount)
        case .typeMismatch(let index):
            // TODO: We need all indices
            throw FunctionError.typeMismatch(index.first! + 1, "int or double")
        default: //
            return .binary(function, lBound, rBound)
        }

    case let .function(name, arguments):
        guard let function = functions[name] else {
            throw ExpressionError.unknownFunction(name)
        }
        
        let boundArgs = try arguments.map {
            try bindExpression($0, variables: variables, functions: functions)
        }

        let types = boundArgs.map { $0.valueType }
        let result = function.signature.validate(types)

        switch result {
        case .invalidNumberOfArguments:
            throw ExpressionError.functionError(
                .invalidNumberOfArguments(arguments.count,
                                          function.signature.minimalArgumentCount))
        case .typeMismatch(let index):
            // TODO: We need all indices
            throw ExpressionError.functionError(.typeMismatch(index.first! + 1, "int or double"))
        default: //
            return .function(function, boundArgs)
        }

    case let .variable(name):
        guard let ref = variables[name] else {
            throw ExpressionError.unknownVariable(name)
        }
        return .variable(ref)
    }
}


extension BoundExpression {
    /// Evaluates an expression using given variables.
    ///
    /// - Parameters:
    ///     - variables: A dictionary of variables to be used during evaluation.
    ///       The keys are variable references and the values are variable
    ///       values. See note below about the requirements.
    ///
    /// The variables dictionary must contain all references that are used in
    /// the expression and its children. It is in the responsibility of the
    /// caller to make sure that all the references are valid. Not having
    /// a required reference in the dictionary results in a fatal error.
    ///
    /// The values in the dictionary are expected to be of the type required
    /// by the evaluation.
    ///
    /// - Returns: result of the evaluation.
    ///
    /// - Throws: ``ValueError``.
    ///
    ///
    public func evaluate(_ variables: [BoundVariableReference:ForeignValue]) throws -> ForeignValue {
        switch self {
        case let .value(value):
            return value

        case let .binary(op, lhs, rhs):
            return try op.apply([try lhs.evaluate(variables),
                                 try rhs.evaluate(variables)])

        case let .unary(op, operand):
            return try op.apply([try operand.evaluate(variables)])

        case let .function(functionRef, arguments):
            let evaluatedArgs = try arguments.map {
                try $0.evaluate(variables)
            }
            return try functionRef.apply(evaluatedArgs)

        case let .variable(ref):
            guard let value = variables[ref] else {
                fatalError("Unknown variable with reference: \(ref). This is internal error, not user error, potentially caused by the compiler.")
            }
            return value
        }
    }
}
