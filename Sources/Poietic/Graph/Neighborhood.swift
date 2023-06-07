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


public class NeighborhoodSelector {
    let direction: EdgeDirection
    let predicate: EdgePredicate
    
    init(predicate: EdgePredicate,
         direction: EdgeDirection) {
        self.predicate = predicate
        self.direction = direction
    }
}


public class Neighborhood {
    let graph: Graph
    let nodeID: ObjectID
    let selector: NeighborhoodSelector
    let edges: [Edge]
    
    init(graph: Graph,
         nodeID: ObjectID,
         selector: NeighborhoodSelector,
         edges: [Edge]) {
        
        self.graph = graph
        self.nodeID = nodeID
        self.selector = selector
        self.edges = edges
    }
    
    public var nodes: [Node] {
        edges.map { edge in
            let endpointID: ObjectID
            switch self.selector.direction {
            case .incoming: endpointID = edge.origin
            case .outgoing: endpointID = edge.target
            }
            let node = graph.node(endpointID)!
            return node
        }
    }
}
