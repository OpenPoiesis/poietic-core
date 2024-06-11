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
public final class Variable: Hashable, Sendable {
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
    
    public static func ==(lhs: Variable, rhs: Variable) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
