//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 26/06/2023.
//


/// Defines a reusable group of attributes that can be associated with object types.
///
/// ## Purpose
///
/// Traits serve several purposes:
/// - **Reusability**: Define attributes once, use them across multiple object types
/// - **Organization**: Group related attributes logically (e.g., all formula-related attributes)
/// - **Foreign interfaces**: Enable reflection and data interchange by advertising object capabilities
///
/// ## Attribute Namespaces
///
/// When multiple traits are associated with an ``ObjectType``, all attributes from all traits
/// share the same namespace. This means:
/// - No two traits on the same object type can define attributes with the same name
/// - The ``ObjectType`` initializer enforces this constraint with a precondition
/// - Attributes can be queried by name on the object type, regardless of which trait defines them


/// Trait defines object details, its attributes or its role in the model.
///
/// Typically trait defines one or more attributes that together form a logical characteristics
/// of an object, such as formula, position, or a definition of a numeric indicator. Traits
/// can be also without attributes and just define roles of objects, such as simulation object.
///
/// ## Attribute Namespaces
///
/// When multiple traits are associated with an ``ObjectType``, all attributes from all traits
/// share the same namespace. This means:
/// - No two traits on the same object type can define attributes with the same name
/// - Attributes can be queried by name on the object type, regardless of which trait defines them
///
/// ## Example
///
/// ```swift
/// let Formula = Trait(
///     name: "Formula",
///     attributes: [
///         Attribute("formula", type: .string, default: "0",
///                   abstract: "Arithmetic expression or constant value")
///     ],
///     abstract: "Provides formula evaluation capability"
/// )
///
/// // Use the trait in multiple object types
/// let Stock = ObjectType(
///     name: "Stock",
///     structuralType: .node,
///     traits: [Trait.Name, Formula, Trait.Stock]
/// )
///
/// let Auxiliary = ObjectType(
///     name: "Auxiliary",
///     structuralType: .node,
///     traits: [Trait.Name, Formula, Trait.Auxiliary]
/// )
/// ```
///
/// - Note: All user-entered attributes should be included in the trait's attribute list
///         to support data interchange and foreign interfaces.
/// - SeeAlso: ``ObjectType``, ``Attribute``, ``Metamodel``
///
public final class Trait: Sendable {
    /// Name identifier of the trait.
    ///
    /// Example: `"Formula"`, `"Stock"`, `"DiagramBlock"`
    ///
    /// - SeeAlso: ``ObjectType/hasTrait(_:)``
    ///
    public let name: String
    
    /// Human-readable label of the trait that is to be displayed to the
    /// user.
    ///
    /// Default value is the same as the trait name.
    ///
    public let label: String
    
    /// List of trait attributes.
    ///
    /// - Important: Attributes names share the same namespace within an object.
    ///
    public let attributes: [Attribute]
    
    /// Human-readable short description of the trait.
    ///
    /// Recommended content is one-sentence description of the trait.
    ///
    /// Example use of the abstract might be a tool-tip or a command-line
    /// description of a model.
    ///
    ///
    public let abstract: String?
    
    /// Creates a new trait.
    ///
    /// - Parameters:
    ///     - name: Name of the trait.
    ///     - label: User-oriented label of the trait. If not provided, then
    ///       name is used.
    ///     - attributes: List of descriptions of component's attributes. If empty, then the trait
    ///       is used only as a tag.
    ///     - abstract: Short description of the trait, usually displayed as
    ///       a tool-tip.
    ///
    public init(name: String,
                label: String? = nil,
                attributes: [Attribute] = [],
                abstract: String? = nil) {
        self.name = name
        self.label = label ?? name.titleCase()
        self.attributes = attributes
        self.abstract = abstract
    }
    
    public var description: String {
        let attrStr = attributes.map { $0.description }.joined(separator: ", ")
        return "\(name)(\(attrStr))"
    }
}

/// Description of a single attribute within a ``Trait``.
///
/// Attributes define the data properties that objects can possess. Each attribute specifies:
/// - A name and an optional human readable label
/// - Data type, used also for validation
/// - Whether the attribute is required or optional
/// - A default value (for optional attributes or initialisation)
///
/// - Note: Within an ``ObjectType``, all attributes from all associated ``Trait``s share the same
///   namespace. No two traits on the same object type can define attributes with the same name.
public final class Attribute: CustomStringConvertible, Sendable {
    /// Attribute name – a unique identifier within the object type.
    ///
    /// Must be unique across all traits associated with an object type.
    /// Typically uses snake_case convention (e.g., `"min_value"`, `"formula"`).
    ///
    public let name: String

    /// Data type of the attribute value.
    ///
    /// Determines which ``Variant`` values are valid for this attribute.
    ///
    /// Common types: `.string`, `.int`, `.double`, `.bool`, `.point`, `.points`
    ///
    /// - SeeAlso: ``VariableType``, ``Variant``
    ///
    public let type: VariableType

    /// Default value assigned to the attribute if not provided during object creation.
    ///
    /// - For required attributes: Specifies the initial value
    /// - For optional attributes: May be `nil` or provide a default
    ///
    /// The value must match the attribute's ``type``.
    ///
    public let defaultValue: Variant?
    
    /// Flag whether the attribute is optional.
    ///
    /// - `false` (default): The attribute must have a value (either provided explicitly during
    ///   object creation or via ``defaultValue``)
    /// - `true`: The object might not contain the attribute. Note that the attributes can not be `nil`.
    ///
    public let optional: Bool
    
    /// User-facing label for the attribute.
    ///
    /// Used in user interfaces for property inspectors, forms, and documentation.
    /// If not provided during initialisation, a title-cased version of ``name`` is used.
    ///
    public let label: String

    /// Short human-readable description of the attribute.
    public let abstract: String?

    // TODO: Add "audience level"
    // TODO: Remove label and abstract - move to "DocumentationItem"
    
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
        self.label = label ?? name.titleCase()
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
