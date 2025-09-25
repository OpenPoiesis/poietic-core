//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

extension TransientDesign /* MutableGraph (no longer formally present) */ {
    /// Convenience method to create an edge.
    ///
    /// If the object name is provided, then attribute `name` of the
    /// object is set. Replaces `name` attribute in the `attributes` dictionary.
    ///
    /// - SeeAlso: ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
    /// - Precondition: Frame must contain objects with given origin and target object IDs.
    /// - Precondition: The object type must have structural type ``StructuralType/edge``.
    @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: ObjectID,
                           target: ObjectID,
                           attributes: [String:Variant] = [:]) -> TransientObject {
        precondition(type.structuralType == .edge, "Structural type mismatch")
        precondition(contains(origin), "Missing edge origin")
        precondition(contains(target), "Missing edge target")

        let snapshot = create(type, structure: .edge(origin, target), attributes: attributes)
        
        return snapshot
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
                           attributes: [String:Variant] = [:]) -> TransientObject {
            precondition(type.structuralType == .node, "Structural type mismatch")

        var actualAttributes = attributes
        
        if let name {
            actualAttributes["name"] = Variant(name)
        }
        
        let snapshot = create(type, structure: .node, attributes: actualAttributes)

        return snapshot
    }

    public func remove(node nodeID: ObjectID) {
        removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        removeCascading(edgeID)
    }
}
