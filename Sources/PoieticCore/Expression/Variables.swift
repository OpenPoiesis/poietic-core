//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/09/2023.
//

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
    /// Name of the variable.
    ///
    /// The name of the variable is used in arithmetic expressions to refer
    /// to the variable.
    ///
    public let name: String
    
    /// Default value of the built-in variable.
    ///
    public let initialValue: Variant?
    
    /// Human-readable description of the variable.
    public let abstract: String?
    
    /// Data type of the variable value.
    ///
    public let valueType: ValueType = .double
    
    /// Create a new built-in variable.
    ///
    /// - Parameters:
    ///     - name: Name of the variable
    ///     - value: Default value of the variable.
    ///     - abstract: short human description of the variable.
    ///
    public init(name: String,
                value: Variant? = nil,
                abstract: String?) {
        self.name = name
        self.initialValue = value
        self.abstract = abstract
    }
    
    public static func ==(lhs: BuiltinVariable, rhs: BuiltinVariable) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}


// FIXME: [REFACTORING] Reconsider existence of this protocol
/// Protocol for types that can represent one or multiple variant types.
///
public protocol TypedValue {
    var valueType: ValueType { get }
}

extension Variant: TypedValue {
    public var unionType: UnionType {
        return .concrete(valueType)
    }
    
}
/// Reference to a variable.
///
/// The variable reference is used in arithmetic expressions and might represent
/// a built-in variable provided by the application or a value of an object.
///
/// One object can represent only one variable.
///
public enum VariableReference: Hashable, CustomStringConvertible {
    /// The variable is represented by an object with given object ID.
    ///
    case object(ObjectID)
    
    /// The variable is a built-in variable.
    ///
    case builtin(BuiltinVariable)
    
    public static func ==(lhs: VariableReference, rhs: VariableReference) -> Bool {
        switch (lhs, rhs) {
        case let (.object(left), .object(right)): return left == right
        case let (.builtin(left), .builtin(right)): return left === right
        default: return false
        }
    }

    public var description: String {
        switch self {
        case .object(let id): "object(\(id))"
        case .builtin(let variable): "builtin(\(variable.name))"
        }
    }
}
