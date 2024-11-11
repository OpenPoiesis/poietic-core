//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 26/06/2023.
//


/// Description of a component.
///
/// The component description object represents detailed information about the
/// component that is used for reflection and foreign interfaces.
///
/// Component is expected to include description of all attributes that
/// represent user-entered data so that user's data can be extracted and used
/// in data interchange (inspection, foreign interfaces, scripting, ...).
///
/// - Note: The attributes in components share the same name-space within an
///         object type. In other words, there must not be two components with
///         the same attribute in an object type.
///
/// - SeeAlso: ``Component``
///
public final class Trait: Sendable {
    /// Name of the component.
    ///
    /// The component name is used in reflection and when a component is being
    /// created by its name from a foreign data representation.
    ///
    public let name: String
    
    /// Human-readable label of the component that is to be displayed to the
    /// user.
    ///
    /// Default value is the same as the component name.
    ///
    public let label: String
    
    /// List of public attributes of the component.
    ///
    /// The component must advertise all attributes that represent data entered
    /// by the user. Advertising derived attributes is optional.
    ///
    /// - Important: Attributes names share the same namespace within an object.
    ///   If two components provide an attribute `name` and there is no
    ///   model validation in place, then which `name` will be used is
    ///   undeterminable.
    ///
    /// - SeeAlso: ``ObjectSnapshot/subscript(attributeKey:)``,
    ///   ``MutableObject/subscript(key:)``
    ///
    public let attributes: [Attribute]
    
    /// Human-readable short description of the component.
    ///
    /// Recommended content is one-sentence description of the component.
    ///
    /// Example use of the abstract might be a tool-tip or a command-line
    /// description of a model.
    ///
    ///
    public let abstract: String?
    
    /// Create a new component description.
    ///
    /// - Parameters:
    ///     - name: Name of the component.
    ///     - label: User-oriented label of the component. If not provided, then
    ///       attribute name is used.
    ///     - attributes: List of descriptions of component's public
    ///       user-oriented attributes.
    ///     - abstract: Short description of the component, usually displayed as
    ///         a tool-tip.
    ///
    public init(name: String,
                label: String? = nil,
                attributes: [Attribute] = [],
                abstract: String? = nil) {
        self.name = name
        self.label = label ?? name
        self.attributes = attributes
        self.abstract = abstract
    }
    
    public var description: String {
        let attrStr = attributes.map { $0.description }
            .joined(separator: ", ")

        return "\(name)(\(attrStr))"
    }
}

/// Description of an attribute.
///
/// Each public user-oriented attribute of a ``Component`` must have a
/// description. The attribute description is used in foreign interfaces,
/// such as data interchange, data storage or scripting.
///
/// - Note: The attributes in components share the same name-space within an
///         object type. In other words, there must not be two components with
///         the same attribute in an object type.
///
public final class Attribute: CustomStringConvertible, Sendable {
    /// Attribute name – an identifier.
    ///
    public let name: String

    /// Data type of the attribute.
    ///
    public let type: VariableType

    public let defaultValue: Variant?
    
    public let optional: Bool
    
    /// User-oriented label.
    ///
    /// If no label is provided, then the attribute name will be used.
    public let label: String

    /// Short description of the attribute.
    public let abstract: String?

    // TODO: Add "audience level"
    
    /// Create a new attribute description.
    ///
    /// - Parameters:
    ///     - name: Name of the attribute. See ``Component`` description
    ///       for more attribute names and their namespaces.
    ///     - type: Data type of the attribute.
    ///     - defaultValue: Default value of the attribute if not provided
    ///       otherwise during initialisation.
    ///     - optional: Flag whether the attribute is optional.
    ///     - label: User-oriented label of the attribute. If none provided,
    ///         then the attribute name will be used.
    ///     - abstract: Short description of the attribute, usually displayed as
    ///         a tool-tip.
    ///
    public init(_ name: String,
                type: VariableType,
                default defaultValue: Variant? = nil,
                optional: Bool = false,
                label: String?=nil,
                abstract: String? = nil) {
        self.name = name
        self.type = type
        self.optional = optional
        self.defaultValue = defaultValue
        self.label = label ?? name
        self.abstract = abstract
    }
    
    public var description: String {
        "(\(name):\(type))"
    }
}

extension Attribute: Equatable {
    public static func == (lhs: Attribute, rhs: Attribute) -> Bool {
        return lhs.name == rhs.name
        && lhs.type == rhs.type
        && lhs.defaultValue == rhs.defaultValue
        && lhs.optional == rhs.optional
        && lhs.label == rhs.label
        && lhs.abstract == rhs.abstract
    }
}
