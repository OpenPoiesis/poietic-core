//
//  FrameIndex.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 26/04/2025.
//

class _FrameIndex {
    internal let idMap: [ObjectID:DesignObject]
    internal let outgoingEdges: [ObjectID:[EdgeObject]]
    internal let incomingEdges: [ObjectID:[EdgeObject]]
    internal let unstructured: [DesignObject]
    internal let nodes: [DesignObject]
    internal let edges: [EdgeObject]
    internal let edgeIDs: [ObjectID]
    internal let nodeIDs: [ObjectID]
    
    init(_ snapshots: [DesignObject]) {
        var map: [ObjectID:DesignObject] = [:]
        var unstructured: [DesignObject] = []
        var nodes: [DesignObject] = []
        var edges: [EdgeObject] = []
        var outgoingEdges: [ObjectID:[EdgeObject]] = [:]
        var incomingEdges: [ObjectID:[EdgeObject]] = [:]
        var nodeIDs: [ObjectID] = []
        var edgeIDs: [ObjectID] = []

        for snapshot in snapshots {
            map[snapshot.id] = snapshot
        }
        for snapshot in snapshots {
            switch snapshot.structure {
            case .unstructured:
                unstructured.append(snapshot)
            case .node:
                nodes.append(snapshot)
                nodeIDs.append(snapshot.id)
            case .edge(let origin, let target):
                let edge = EdgeObject(snapshot, origin: map[origin]!, target: map[target]!)
                edges.append(edge)
                edgeIDs.append(edge.id)
                outgoingEdges[origin, default: []].append(edge)
                incomingEdges[target, default: []].append(edge)
            case .orderedSet(let owner, let items):
                fatalError("Ordered set not implemented in \(#function)")
            }

        }
        
        self.idMap = map
        self.nodes = nodes
        self.nodeIDs = nodeIDs
        self.edges = edges
        self.edgeIDs = edgeIDs
        self.outgoingEdges = outgoingEdges
        self.incomingEdges = incomingEdges
        self.unstructured = unstructured
    }
    
}
