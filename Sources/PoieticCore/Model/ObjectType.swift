//
//  ObjectType.swift
//
//
//  Created by Stefan Urbanek on 31/05/2023.
//

/// Object representing a type of a design object.
///
/// ObjectType describes instances of an object – what are their components,
/// what are their structural types.
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
    public let structuralType: StructuralType
    
    /// List of component requirements for objects of this type.
    ///
    public let traits: [Trait]
    
    /// Short description and the purpose of the object type.
    ///
    /// It is recommended that metamodel creators provide this attribute.
    ///
    public let abstract: String?

    /// Mapping between attribute name and a component type that contains the
    /// attribute.
    ///
    /// - Note: The attributes in the components share the same name-space
    /// within the object type.
    let attributeTraits: [String:Trait]
    let attributeByName: [String:Attribute]

    /// Ordered list of all attributes.
    ///
    public let attributes: [Attribute]
    
    public var attributeKeys: [AttributeKey] { attributes.map { $0.name } }

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
    ///
    /// - Note: The attributes in components share the same name-space within an
    ///         object type. In other words, there must not be two components with
    ///         the same attribute in an object type.
    /// - Precondition: There must be no duplicate attribute names in the
    ///   components.
    ///
    public init(name: String,
                label: String? = nil,
                structuralType: StructuralType,
                traits: [Trait] = [],
                abstract: String? = nil) {
        self.name = name
        self.label = label ?? name
        self.structuralType = structuralType
        self.traits = traits
        self.abstract = abstract
        
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
   
    public func hasTrait(_ trait: Trait) -> Bool {
        traits.contains { $0 === trait }
    }
    
    public func hasAttribute(_ name: String) -> Bool {
        attributeByName[name] != nil
    }
    
    public func trait(forAttribute name: String) -> Trait? {
        attributeTraits[name]
    }
    
    public func attribute(_ name: String) -> Attribute? {
        return attributeByName[name]
    }
}
