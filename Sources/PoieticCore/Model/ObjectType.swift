//
//  ObjectType.swift
//
//
//  Created by Stefan Urbanek on 31/05/2023.
//

/// Specification of an object type requirement for presence of a component.
///
public enum ComponentRequirement {
    // TODO: Is this still needed?
    
    /// Component is required by the object type. If not present, then it
    /// is considered a constraint violation.
    ///
    case required(Component.Type)

    /// Component's presence is optional in an object type, but it will be
    /// created during object creation.
    ///
    case defaultValue(Component.Type)

    public var description: String {
        switch self{
        case .required(let type):
            return "\(type.componentDescription.label) (required)"
        case .defaultValue(let type):
            return "\(type.componentDescription.label) (optional)"
        }
    }
}

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
    public let components: [ComponentRequirement]

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
    public init(name: String,
                label: String? = nil,
                structuralType: StructuralType,
                components: [ComponentRequirement]) {
        self.name = name
        self.label = label ?? name
        self.structuralType = structuralType
        self.components = components
    }
}
