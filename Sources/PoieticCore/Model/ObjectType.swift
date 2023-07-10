//
//  ObjectType.swift
//
//
//  Created by Stefan Urbanek on 31/05/2023.
//

/// Structural type of an object.
///
/// Structural type denotes how the object can relate to other objects in
/// the design.
///
public enum StructuralType: String, Equatable {
    /// Plain object without any relationships with other objects,
    /// has no dependencies and no objects depend on it.
    case object
    
    /// Graph component representing a node. Can be connected to other nodes
    /// through an edge.
    case node
    
    /// Graph component representing a connection between two nodes.
    case edge
}

/// Object representing a type of a design object.
///
/// ObjectType describes instances of an object – what are their components,
/// what are their structural types.
///
public class ObjectType {
    // TODO: Rename to "ObjectClass" (referred to as 'Class' within the system, yet not to conflict with Class in the host language)
    
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
    
    /// Flag whether the objects of this type are being created by the
    /// system
    ///
    /// Objects of this type are usually derived from other user objects and
    /// placed into the design, so a user interface or a tool can present the
    /// derived information to the user.
    ///
    /// Users or any external tools must not be allowed to create objects of
    /// this type.
    ///
    public let isSystemOwned: Bool
    
    /// List of component requirements for objects of this type.
    ///
    public let components: [Component.Type]
    
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
    public let _attributeComponentMap: [String:Component.Type]
    
    /// Create a new object type.
    ///
    /// - Parameters:
    ///     - name: Name of the object type.
    ///     - label: Label of the object type. If not provided, then the
    ///       name is used.
    ///     - structuralType: Specification how the object can be related to
    ///       other objects in the design.
    ///     - components: Specification of components that are required to be
    ///       present for an object of this type.
    ///
    /// - Note: The attributes in components share the same name-space within an
    ///         object type. In other words, there must not be two components with
    ///         the same attribute in an object type.
    ///
    public init(name: String,
                label: String? = nil,
                structuralType: StructuralType,
                isSystemOwned: Bool = false,
                components: [Component.Type],
                abstract: String? = nil) {
        self.name = name
        self.label = label ?? name
        self.structuralType = structuralType
        self.isSystemOwned = isSystemOwned
        self.components = components
        self.abstract = abstract
        
        let pairs: [(String, Component.Type)] = components.flatMap { component in
            let desc = component.componentDescription
            return desc.attributes.map { ($0.name, component) }
        }
        self._attributeComponentMap = Dictionary(uniqueKeysWithValues: pairs)

    }
    
    /// List of attributes from all components.
    ///
    public var attributes: [AttributeDescription] {
        return components.flatMap {
            $0.componentDescription.attributes
        }
    }
    
    public func hasAttribute(_ name: String) -> Bool {
        return _attributeComponentMap[name] != nil
    }
    
    public func componentType(forAttribute name: String) -> Component.Type? {
        return _attributeComponentMap[name]
    }
    
    public func attribute(_ name: String) -> AttributeDescription? {
        guard let component = componentType(forAttribute: name) else {
            return nil
        }
        return component.componentDescription.attributes.first {
            $0.name == name
        }
    }
}
