//
//  StructuralComponent.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Foundation

/// Structural type of an object.
///
/// Structural type denotes how the object can relate to other objects in
/// the design.
///
public enum StructuralType: String, Equatable {
    /// Plain object without any relationships with other objects,
    /// has no dependencies and no objects depend on it.
    case unstructured
    
    /// Graph component representing a node. Can be connected to other nodes
    /// through an edge.
    case node
    
    /// Graph component representing a connection between two nodes.
    case edge
}

public enum StructuralComponent: Equatable {
    case unstructured
    case node
    case edge(ObjectID, ObjectID)
    
    public var type: StructuralType {
        switch self {
        case .unstructured: .unstructured
        case .node: .node
        case .edge: .edge
        }
    }
}
