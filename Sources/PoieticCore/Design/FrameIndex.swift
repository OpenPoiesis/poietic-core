//
//  FrameIndex.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 26/04/2025.
//

// FIXME: [WIP] Reflect filename
/// An immutable index for fast traversal of snapshot relationships (edges, nodes, ordered sets).
///
/// - Requires: All `ObjectID`s in `snapshots` must be valid (caller ensures referential integrity).
///
class StructuralSnapshotIndex {
    // FIXME: [WIP] Replace with property graph
    internal let idMap: [ObjectID:ObjectSnapshot]
    internal let outgoingEdges: [ObjectID:[EdgeObject]]
    internal let incomingEdges: [ObjectID:[EdgeObject]]
    internal let orders: [ObjectID:OrderedSet<ObjectID>]
    internal let unstructured: [ObjectSnapshot]
    internal let nodes: [ObjectSnapshot]
    internal let edges: [EdgeObject]
    internal let edgeIDs: [ObjectID]
    internal let nodeIDs: [ObjectID]
    
    init(_ snapshots: [ObjectSnapshot]) {
        var map: [ObjectID:ObjectSnapshot] = [:]
        var unstructured: [ObjectSnapshot] = []
        var nodes: [ObjectSnapshot] = []
        var edges: [EdgeObject] = []
        var outgoingEdges: [ObjectID:[EdgeObject]] = [:]
        var incomingEdges: [ObjectID:[EdgeObject]] = [:]
        var nodeIDs: [ObjectID] = []
        var edgeIDs: [ObjectID] = []
        var orders: [ObjectID:OrderedSet<ObjectID>] = [:]

        for snapshot in snapshots {
            map[snapshot.objectID] = snapshot
        }
        for snapshot in snapshots {
            switch snapshot.structure {
            case .unstructured:
                unstructured.append(snapshot)
            case .node:
                nodes.append(snapshot)
                nodeIDs.append(snapshot.objectID)
            case .edge(let origin, let target):
                let edge = EdgeObject(snapshot, origin: map[origin]!, target: map[target]!)
                edges.append(edge)
                edgeIDs.append(edge.key)
                outgoingEdges[origin, default: []].append(edge)
                incomingEdges[target, default: []].append(edge)
            case .orderedSet(let owner, let items):
                orders[owner] = items
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
        self.orders = orders
    }
    
}
