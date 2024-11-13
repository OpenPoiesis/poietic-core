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


/// Neighbourhood is a subgraph centred on a node with edges adjacent to
/// that node.
///
/// Neighbourhoods are created using ``Graph/hood(_:direction:where:)``.
///
public class Neighborhood<G: GraphProtocol> {
    public typealias GraphType = G
    /// Graph the neighbourhood is contained within.
    ///
    public let graph: GraphType
    
    /// ID of a node the neighbourhood adjacent to.
    ///
    public let nodeID: GraphType.Node.ID
    
    /// Direction of the edges to be followed from the main node.
    ///
    public let direction: EdgeDirection
    
    /// List of adjacent edges.
    ///
    public let edges: [G.Edge]
    
    public init(graph: G, nodeID: GraphType.Node.ID, direction: EdgeDirection, edges: [G.Edge]) {
        self.graph = graph
        self.nodeID = nodeID
        self.direction = direction
        self.edges = edges
    }
    
    public var nodes: [G.Node] {
        edges.map { edge in
            let endpointID: GraphType.Node.ID
            switch direction {
            case .incoming: endpointID = edge.origin
            case .outgoing: endpointID = edge.target
            }
            let node = graph.node(endpointID)
            return node
        }
    }
}
