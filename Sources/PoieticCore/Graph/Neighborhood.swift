//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

/// Designation of which direction of an edge from a node projection perspective
/// is to be considered.
///
public enum EdgeDirection {
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

// TODO: Do we still need this? Can't we just have predicate + direction in the hood?
public class NeighborhoodSelector {
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

public class Neighborhood {
    public let graph: Graph
    public let nodeID: ObjectID
    public let direction: EdgeDirection
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

public class NeighborhoodView {
    public let graph: Graph
    public let nodeID: ObjectID
    public let predicate: Predicate
    public let direction: EdgeDirection

    public var node: Node {
        graph.node(nodeID)
    }
    
    var edges: [Edge] {
        let edges: [Edge]
        switch direction {
        case .incoming: edges = graph.incoming(nodeID)
        case .outgoing: edges = graph.outgoing(nodeID)
        }
        let filtered: [Edge] = edges.filter {
            predicate.match(frame: graph.frame, object: $0.snapshot)
        }

        return filtered
    }
    
    public init(graph: Graph,
                nodeID: ObjectID,
                predicate: Predicate,
                direction: EdgeDirection = .outgoing) {
        
        self.graph = graph
        self.nodeID = nodeID
        self.predicate = predicate
        self.direction = direction
    }
    
    public var nodes: [Node] {
        edges.map { edge in
            switch direction {
            case .incoming: graph.node(edge.origin)
            case .outgoing: graph.node(edge.target)
            }
        }
    }
}


public class BoundNeighborhood {
    public let graph: Graph
    public let node: Node
    public let nodeID: ObjectID
    public let predicate: Predicate
    public let direction: EdgeDirection
    public let edges: [Edge]
    public let nodes: [Node]
    
    public init(graph: Graph,
                nodeID: ObjectID,
                predicate: Predicate,
                direction: EdgeDirection = .outgoing) {
        
        self.graph = graph
        self.nodeID = nodeID
        self.node = graph.node(nodeID)
        self.predicate = predicate
        self.direction = direction

        let edges: [Edge]
        switch direction {
        case .incoming: edges = graph.incoming(nodeID)
        case .outgoing: edges = graph.outgoing(nodeID)
        }
        let filtered: [Edge] = edges.filter {
            predicate.match(frame: graph.frame, object: $0.snapshot)
        }

        self.edges = filtered
        self.nodes = edges.map { edge in
            switch direction {
            case .incoming: graph.node(edge.origin)
            case .outgoing: graph.node(edge.target)
            }
        }

    }
}

