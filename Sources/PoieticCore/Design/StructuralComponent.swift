//
//  StructuralComponent.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

/// Structural type of an object.
///
/// Structural type denotes how the object can relate to other objects in
/// the design.
///
public enum StructuralType: String, Equatable, Codable, Sendable {
    /// Plain object without any relationships with other objects,
    /// has no dependencies and no objects depend on it.
    case unstructured
    
    /// Graph component representing a node. Can be connected to other nodes
    /// through an edge.
    case node
    
    /// Graph component representing a connection between two nodes.
    case edge
}

/// Structural component defines object's relationship with other objects.
///
/// Structural component is another way of specifying object structure
/// besides the parent-child hierarchy.
///
/// - SeeAlso: ``ObjectSnapshot/children``, ``ObjectSnapshot/parent``
///
public enum StructuralComponent: Equatable, CustomStringConvertible {
    /// The object has no relationships with other objects,
    /// has no structural dependencies and no objects depend on it.
    ///
    /// Unstructured objects can not be part of a graph, they can not
    /// be referenced by edges.
    ///
    /// Object still might be part of a hierarchical parent-child structure.
    ///
    case unstructured
    
    /// The object with this component is part of a graph and represents a node.
    ///
    /// Node objects can be referenced by objects of type edge.
    ///
    /// When a node is removed from a frame, all objects with structural
    /// component ``edge(_:_:)`` that refer to the removed node are removed
    /// as well. See ``TransientFrame/removeCascading(_:)`` for more information.
    ///
    /// - SeeAlso: ``edge(_:_:)``
    ///
    case node

    /// The object with this component is part of a graph and represents an
    /// edge - a link between two nodes.
    ///
    /// When one of the objects referenced by the edge component is removed
    /// from a frame, then the object with the edge component is removed
    /// as well. See ``TransientFrame/removeCascading(_:)`` for more information.
    ///
    /// - SeeAlso: ``node``
    ///
    case edge(ObjectID, ObjectID)
    
    /// A structural type of the component.
    ///
    public var type: StructuralType {
        switch self {
        case .unstructured: .unstructured
        case .node: .node
        case .edge: .edge
        }
    }
    
    /// Short description of the structural component.
    public var description: String {
        switch self {
        case .unstructured: "unstructured"
        case .node: "node"
        case .edge(let origin, let target): "edge(\(origin),\(target))"
        }
    }
}
