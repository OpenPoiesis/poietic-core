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

public protocol TypedValue {
    var valueType: AtomType? { get }
}

extension ForeignValue: TypedValue {
}
/// Reference to a variable.
///
/// The variable reference is used in arithmetic expressions and might represent
/// a built-in variable provided by the application or a value of an object.
///
/// One object can represent only one variable.
///
public enum VariableReference: Hashable, CustomStringConvertible {
    case object(ObjectID)
    case builtin(BuiltinVariable)
    
    public static func ==(lhs: VariableReference, rhs: VariableReference) -> Bool {
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
