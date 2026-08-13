//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

extension TransientPlane /* MutableGraph (no longer formally present) */ {
    /// Convenience method to create an edge.
    ///
    /// If the object name is provided, then attribute `name` of the
    /// object is set. Replaces `name` attribute in the `attributes` dictionary.
    ///
    /// - SeeAlso: ``TransientPlane/create(_:objectID:snapshotID:topology:parent:children:attributes:)``
    /// - Precondition: Plane must contain objects with given origin and target object IDs.
    /// - Precondition: The object type must have structural type ``TopologyType/edge``.
    @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: ObjectID,
                           target: ObjectID,
                           attributes: [String:Variant] = [:]) -> TransientObject {
        precondition(type.topologyType == .edge, "Structural type mismatch")
        precondition(contains(origin), "Missing edge origin")
        precondition(contains(target), "Missing edge target")

        let snapshot = create(type, topology: .edge(origin, target), attributes: attributes)
        
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
            precondition(type.topologyType == .node, "Structural type mismatch")

        var actualAttributes = attributes
        
        if let name {
            actualAttributes["name"] = Variant(name)
        }
        
        let snapshot = create(type, topology: .node, attributes: actualAttributes)

        return snapshot
    }

    public func remove(node nodeID: ObjectID) {
        removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        removeCascading(edgeID)
    }
}
