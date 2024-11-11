//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

/// Designation of which direction of an edge from a node projection perspective
/// is to be considered.
///
public enum EdgeDirection: Sendable {
    /// Direction that considers edges where the node projection is the target.
    case incoming
    /// Direction that considers edges where the node projection is the origin.
    case outgoing
    
    /// Reversed direction. For ``incoming`` reversed is ``outgoing`` and
    /// vice-versa.
    ///
    public var reversed: EdgeDirection {
        switch self {
        case .incoming: return .outgoing
        case .outgoing: return .incoming
        }
    }
}

// FIXME: [CLEANUP] Remove this and follow the TODO below.
// TODO: Do we still need this? Can't we just have predicate + direction in the hood?
public final class NeighborhoodSelector: Sendable {
    public let direction: EdgeDirection
    public let predicate: Predicate
    
    public init(predicate: Predicate,
         direction: EdgeDirection) {
        self.predicate = predicate
        self.direction = direction
    }
}

// TODO: [EXPERIMENTAL] The following is experimental
// TODO: Rethink Neighbourhoods. They are useful, but not well implemented
// TODO: Split this into Bound and Unbound
// TODO: Document complexity O(n) - all edges are traversed

// NOTE: There used to be more evolved neighbourhood-like collection of
//       objects in the past. This is what remained.

/// Neighbourhood is a subgraph centred on a node with edges adjacent to
/// that node.
///
/// Neighbourhoods are created using ``Graph/hood(_:selector:)``.
///
public class Neighborhood {
    /// Graph the neighbourhood is contained within.
    ///
    public let graph: Graph
    
    /// ID of a node the neighbourhood adjacent to.
    ///
    public let nodeID: ObjectID
    
    /// Direction of the edges to be followed from the main node.
    ///
    public let direction: EdgeDirection
    
    /// List of adjacent edges.
    ///
    public let edges: [Edge]
    
    public init(graph: Graph,
                nodeID: ObjectID,
                direction: EdgeDirection,
                edges: [Edge]) {
        
        self.graph = graph
        self.nodeID = nodeID
        self.direction = direction
        self.edges = edges
    }
    
    public var nodes: [Node] {
        edges.map { edge in
            let endpointID: ObjectID
            switch direction {
            case .incoming: endpointID = edge.origin
            case .outgoing: endpointID = edge.target
            }
            let node = graph.node(endpointID)
            return node
        }
    }
}
