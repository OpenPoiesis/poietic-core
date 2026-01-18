//
//  ObjectType.swift
//
//
//  Created by Stefan Urbanek on 31/05/2023.
//

/// Object defining a type of a design object.
///
/// ObjectType describes instances of an object – what are their attributes or traits,
/// what is their structural role within the design graph.
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
    
    /// Structural type of the object – how the object can relate to other
    /// objects in the design.
    ///
    /// - SeeAlso: ``EdgeRule``, ``Metamodel/edgeRules``
    ///
    public let structuralType: StructuralType
    
    /// List of traits for objects of this type.
    ///
    /// - Note: Trait attributes share the same namespace. Two traits associated with an object can
    ///         not have the same attribute name.
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
    
    /// Name of an attribute that is used as primary label of the object. Defaults to `name`.
    ///
    public let labelAttribute: String?
    
    /// Name of an attribute that is used as secondary label of the object.
    ///
    /// For example: `formula`, `delay_time`.
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
    ///   components.
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
