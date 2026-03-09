//
//  ObjectType.swift
//
//
//  Created by Stefan Urbanek on 31/05/2023.
//

/// Defines the type specification for design objects within a metamodel.
///
/// An `ObjectType` specifies:
///
/// - Which traits (and their attributes) objects of this type possess
/// - How objects can relate to other objects in the design graph (via ``structuralType``)
/// - Display properties for user interfaces (labels, primary/secondary attributes)
///
/// Object types are defined within a ``Metamodel`` and validated by the ``ConstraintChecker``.
/// Every object in a design must have a type defined in the design's metamodel.
///
/// ## Structural Types
///
/// The ``structuralType`` property determines the object's role as a graph component:
/// - ``StructuralType/node``: Objects that can be connected via edges
/// - ``StructuralType/edge``: Objects that connect two nodes (requires an ``EdgeRule``)
/// - ``StructuralType/unstructured``: Objects with no graph relationships
///
/// ## Traits and Attributes
///
/// Traits define groups of attributes that objects possess. All attributes from all traits
/// associated with an object type share the same namespace - no two traits in an object type
/// can define attributes with the same name. See ``Trait`` for more information.
///
/// ## Example
///
/// ```swift
/// let Stock = ObjectType(
///     name: "Stock",
///     structuralType: .node,
///     traits: [
///         Trait.Name,
///         Trait.Formula,
///         Trait.Stock,
///     ],
///     abstract: "A reservoir that accumulates quantities over time",
///     secondaryLabelAttribute: "formula"
/// )
///
/// let Flow = ObjectType(
///     name: "Flow",
///     structuralType: .edge,
///     abstract: "Connection between a stock and a flow rate"
/// )
/// ```
///
/// - Note: For edge object types (``structuralType`` is ``StructuralType/edge``),
///         you must define a corresponding ``EdgeRule`` in the metamodel, otherwise
///         edges of this type will fail validation.
///
/// - SeeAlso: ``Metamodel``, ``Trait``, ``EdgeRule``, ``StructuralType``
///
public final class ObjectType: Sendable {
    /// Name of the object type.
    public let name: String
    
    /// User-oriented label of the object type, usually to be displayed in
    /// user interfaces.
    ///
    /// If not provided during initialisation then the `name` is used.
    ///
    public let label: String
    
    /// Structural role of the object in the design graph.
    ///
    /// Determines how the object can relate to other objects:
    /// - `.node`: Can be referenced by edge objects
    /// - `.edge`: Connects two node objects (origin and target)
    /// - `.unstructured`: Cannot participate in graph relationships
    ///
    /// - Note: Edge types require a corresponding ``EdgeRule`` in the metamodel.
    /// - SeeAlso: ``EdgeRule``, ``Metamodel/edgeRules``, ``Structure``
    ///
    public let structuralType: StructuralType
    
    /// Traits associated with this object type.
    ///
    /// Each trait provides a set of attributes that objects of this type will possess.
    /// Attributes from all traits share a single namespace - duplicate attribute names
    /// across traits are not allowed.
    ///
    /// - SeeAlso: ``Trait``, ``attributes``, ``hasAttribute(_:)``
    ///
    public let traits: [Trait]

    /// Short description and the purpose of the object type.
    ///
    /// It is recommended that metamodel creators provide this attribute.
    ///
    public let abstract: String?

    /// Mapping between attribute name and a trait that contains the attribute.
    ///
    /// - Note: The attributes in the traits share the same name-space within the object type.
    ///
    let attributeTraits: [String:Trait]
    let attributeByName: [String:Attribute]

    /// Ordered list of all attributes.
    ///
    public let attributes: [Attribute]
    
    public var attributeKeys: [AttributeKey] { attributes.map { $0.name } }
    
    /// Name of an attribute used as the primary display label for objects of this type.
    ///
    /// Defaults to `"name"`. Set to `nil` if the object type has no primary label attribute.
    ///
    /// User-facing applications typically display this attribute prominently (e.g., as node labels
    /// in diagram editors).
    ///
    /// Example: For a Stock object with `name: "Population"`, the name attribute serves as the label.
    ///
    /// - SeeAlso: ``secondaryLabelAttribute``
    ///
    public let labelAttribute: String?
    
    /// Name of an attribute used as a secondary display label for objects of this type.
    ///
    /// User-facing applications may display this attribute as supplementary information
    /// (e.g., below the primary label in diagram nodes).
    ///
    /// Example: For objects with formulas, setting this to `"formula"` displays the formula
    /// beneath the object name.
    ///
    /// - SeeAlso: ``labelAttribute``
    ///
    public let secondaryLabelAttribute: String?

    /// Create a new object type.
    ///
    /// - Parameters:
    ///     - name: Name of the object type.
    ///     - label: Label of the object type. If not provided, then the
    ///       name is used.
    ///     - structuralType: Specification how the object can be related to
    ///       other objects in the design.
    ///     - traits: List of traits associated with the object type.
    ///     - abstract: User oriented object type details.
    ///     - labelAttribute: Name of an attribute used as a primary label in user-facing
    ///       application.
    ///     - secondaryLabelAttribute: Name of an attribute used as a secondary label in user-facing
    ///       application.
    ///
    /// - Note: The attributes in traits share the same name-space within an
    ///         object type. In other words, there must not be two traits with
    ///         the same attribute in an object type.
    /// - Note: For edge object types (where ``structuralType`` is ``StructuralType/edge``),
    ///         make sure that you have a corresponding ``EdgeRule`` for a metamodel. Otherwise
    ///         the edge will not pass validation.
    /// - Precondition: There must be no duplicate attribute names in the
    ///   traits.
    ///
    public init(name: String,
                label: String? = nil,
                structuralType: StructuralType,
                traits: [Trait] = [],
                abstract: String? = nil,
                labelAttribute: String? = "name",
                secondaryLabelAttribute: String? = nil) {
        self.name = name
        self.label = label ?? name.titleCase()
        self.structuralType = structuralType
        self.traits = traits
        self.abstract = abstract
        self.labelAttribute = labelAttribute
        self.secondaryLabelAttribute = secondaryLabelAttribute
        
        var attributeTraits: [String:Trait] = [:]
        var attributeMap: [String:Attribute] = [:]
        var attributes: [Attribute] = []
        for trait in traits {
            for attr in trait.attributes {
                precondition(attributeTraits[attr.name] == nil,
                             "Object type '\(name)' has duplicate attribute \(attr.name) in trait: \(trait)")

                attributeTraits[attr.name] = trait
                attributeMap[attr.name] = attr
                attributes.append(attr)
            }
        }
        self.attributeTraits = attributeTraits
        self.attributes = attributes
        self.attributeByName = attributeMap

    }
   
    /// Returns `true` of the object type has a given trait.
    ///
    public func hasTrait(_ trait: Trait) -> Bool {
        traits.contains { $0 === trait }
    }

    /// Returns `true` of the object type has a trait with given name.
    ///
    public func hasTrait(_ name: String) -> Bool {
        traits.contains { $0.name == name }
    }

    
    /// Returns `true` of the object type has a given attribute.
    ///
    public func hasAttribute(_ name: String) -> Bool {
        attributeByName[name] != nil
    }
    
    /// Returns a trait with given name, if it is associated with the object type. Otherwise returns
    /// `nil`.
    ///
    public func trait(forAttribute name: String) -> Trait? {
        attributeTraits[name]
    }
    
    /// Returns an attribute with given name, if it is associated with the object type.
    /// Otherwise returns `nil`.
    ///
    public func attribute(_ name: String) -> Attribute? {
        return attributeByName[name]
    }
}
