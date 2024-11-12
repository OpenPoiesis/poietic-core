//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

extension TransientFrame /* MutableGraph (no longer formally present) */ {
    /// Convenience method to create an edge.
    ///
    /// If the object name is provided, then attribute `name` of the
    /// object is set. Replaces `name` attribute in the `attributes` dictionary.
    ///
    /// - SeeAlso: ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
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
                     
    /// Convenience method to create an edge.
    ///
    /// If the object name is provided, then attribute `name` of the
    /// object is set. Replaces `name` attribute in the `attributes` dictionary.
    ///
    /// - SeeAlso: ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
    @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: any ObjectSnapshot,
                           target: any ObjectSnapshot,
                           attributes: [String:Variant] = [:]) -> MutableObject {
        // FIXME: [WIP] Still needed?
        return createEdge(type, origin: origin.id, target: target.id, attributes: attributes)
    }
   
    
    /// Convenience method to a new node.
    ///
    /// - Parameters:
    ///     - type: Object type of the newly created node.
    ///     - name: Optional object name. See note below.
    ///     - attributes: Dictionary of attributes to set.
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
