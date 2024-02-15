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
    
    /// List of component requirements for objects of this type.
    ///
    public let components: [Component.Type]
    
    public var inspectableComponents: any Sequence<InspectableComponent.Type> {
        components.compactMap { $0 as? InspectableComponent.Type }
    }
    
    /// Short description and the purpose of the object type.
    ///
    /// It is recommended that metamodel creators provide this attribute.
    ///
    public let abstract: String?

    // TODO: Remove Plane, replace with tags
    /// Plane in which the objects of this type reside.
    ///
    public let plane: Plane
    
    /// Mapping between attribute name and a component type that contains the
    /// attribute.
    ///
    /// - Note: The attributes in the components share the same name-space
    /// within the object type.
    public let _attributeComponentMap: [String:InspectableComponent.Type]
    
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
    /// - Precondition: There must be no duplicate attribute names in the
    ///   components.
    ///
    public init(name: String,
                label: String? = nil,
                structuralType: StructuralType,
                plane: Plane = .user,
                components: [Component.Type] = [],
                abstract: String? = nil) {
        self.name = name
        self.label = label ?? name
        self.structuralType = structuralType
        self.plane = plane
        self.components = components
        self.abstract = abstract
        
        var map: [String:InspectableComponent.Type] = [:]
        for component in components {
            guard let component = component as? InspectableComponent.Type else {
                continue
            }
            for attr in component.componentSchema.attributes {
                guard map[attr.name] == nil else {
                    fatalError("Object type '\(name)' has duplicate attribute \(attr.name) in component: \(component)")
                }
                map[attr.name] = component
            }
        }
        self._attributeComponentMap = map

    }
    
    /// List of attributes from all components.
    ///
    public var attributes: any Sequence<Attribute> {
        inspectableComponents.flatMap {
            $0.componentSchema.attributes
        }
    }
    
    public func hasAttribute(_ name: String) -> Bool {
        _attributeComponentMap[name] != nil
    }
    
    public func componentType(forAttribute name: String) -> InspectableComponent.Type? {
        _attributeComponentMap[name]
    }
    
    public func attribute(_ name: String) -> Attribute? {
        guard let component = componentType(forAttribute: name) else {
            return nil
        }
        return component.componentSchema.attributes.first {
            $0.name == name
        }
    }
}
