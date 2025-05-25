//
//  Frame+Graph.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/05/2025.
//

extension Frame {
    public var nodeKeys: [ObjectID] {
        return self.snapshots.filter { $0.structure.type == .node }.map { $0.objectID }
    }
    
    public var edgeKeys: [ObjectID] {
        return self.snapshots.filter { $0.structure.type == .edge }.map { $0.objectID }
    }

    public var edges: [EdgeObject] {
        return self.snapshots.compactMap {
            EdgeObject($0, in: self)
        }
    }

    // FIXME: [WIP] Review the following disabled graph methods
    /// Get a node by ID.
    ///
    /// - Precondition: The object must exist and must be a node.
    ///
    public func _node(_ id: ObjectID) -> ObjectSnapshot {
        let object = self[id]
        guard object.structure.type == .node else {
            preconditionFailure("Not a node: \(id)")
        }
        return object
    }
    
    /// Get an edge by ID.
    ///
    /// - Precondition: The object must exist and must be an edge.
    ///
    public func _edge(_ id: ObjectID) -> Edge {
        if let edge = Edge(self[id], in: self) {
            return edge
        }
        else {
            preconditionFailure("Not an edge: \(id)")
        }
    }
    
    public func _contains(node nodeID: ObjectID) -> Bool {
        if contains(nodeID) {
            let obj = self[nodeID]
            return obj.structure.type == .node
        }
        else {
            return false
        }
    }
    
    public func _contains(edge edgeID: ObjectID) -> Bool {
        if contains(edgeID) {
            let obj = self[edgeID]
            return obj.structure.type == .edge
        }
        else {
            return false
        }
    }
}

