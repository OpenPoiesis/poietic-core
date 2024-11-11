//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

/// Protocol
public protocol MutableGraph: ObjectGraph {
    // Object creation
    @discardableResult
    func createNode(_ type: ObjectType, name: String?, attributes: [String:Variant]) -> MutableObject
    
    @discardableResult
    func createEdge(_ type: ObjectType, origin: ObjectID, target: ObjectID,
                    attributes: [String:Variant]) -> MutableObject

    /// Remove all nodes and edges from the graph.
    func removeAll()
    
    /// Remove a node from the graph and return a list of edges that were
    /// removed together with the node.
    ///
    func remove(node nodeID: ObjectID)
    
    /// Remove an edge from the graph.
    ///
    func remove(edge edgeID: ObjectID)
}

extension MutableGraph {
    public func removeAll() {
        for edge in edgeIDs {
            remove(edge: edge)
        }
        for node in nodeIDs {
            remove(node: node)
        }
    }
}


/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
extension TransientFrame: MutableGraph {
    // Object creation
    @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: ObjectID,
                           target: ObjectID,
                           attributes: [String:Variant] = [:]) -> MutableObject {
        precondition(type.structuralType == .edge, "Structural type mismatch")
        precondition(contains(origin), "Missing edge origin")
        precondition(contains(target), "Missing edge target")

        let snapshot = create(type, structure: .edge(origin, target), attributes: attributes)
        
        return snapshot
    }
                     
    @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: any ObjectSnapshot,
                           target: any ObjectSnapshot,
                           attributes: [String:Variant] = [:]) -> MutableObject {
        return createEdge(type, origin: origin.id, target: target.id, attributes: attributes)
    }
   
    
    /// Creates a new node.
    ///
    /// - Parameters:
    ///     - type: Object type of the newly created node.
    ///     - name: Optional object name. See note below.
    ///     - attributes: Dictionary of attributes to set.
    ///     - components: List of components assigned with the node.
    ///
    /// If the object name is provided, then attribute `name` of the
    /// object is set. Replaces `name` attribute in the `attributes` dictionary.
    ///
    @discardableResult
    public func createNode(_ type: ObjectType,
                           name: String? = nil,
                           attributes: [String:Variant] = [:]) -> MutableObject {
            precondition(type.structuralType == .node, "Structural type mismatch")

        var actualAttributes = attributes
        
        if let name {
            actualAttributes["name"] = Variant(name)
        }
        
        let snapshot = create(type, attributes: actualAttributes)

        return snapshot
    }

    public func remove(node nodeID: ObjectID) {
        removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        removeCascading(edgeID)
    }
}
