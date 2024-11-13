//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//

/// Protocol for edges in a graph.
///
/// - SeeAlso: ``GraphProtocol``
public protocol EdgeProtocol: Identifiable {
    associatedtype NodeID
    /// Origin of the edge.
    var origin: NodeID { get }
    /// Target of the edge.
    var target: NodeID { get }
}


/// Protocol for object graphs - nodes connected by edges.
///
/// Graphs are used to view interconnected object structures. When you use design frames
/// you will benefit from operations that find neighbourhoods or sort objects topologically.
///
public protocol GraphProtocol {
    associatedtype Node: Identifiable
    associatedtype Edge: EdgeProtocol where Edge.NodeID == Node.ID
    
    /// All nodes of the graph
    var nodes: [Node] { get }
    
    /// All edges of the graph
    var edges: [Edge] { get }
    
    /// Get a node by ID.
    ///
    /// - Precondition: The graph must contain the node.
    ///
    func node(_ index: Node.ID) -> Node
    
    /// Get an edge by ID.
    ///
    /// - Precondition: The graph must contain the edge.
    ///
    func edge(_ index: Edge.ID) -> Edge
    
    /// Check whether the graph contains a node object with given ID.
    ///
    /// - Returns: `true` if the graph contains the node.
    ///
    func contains(node: Node.ID) -> Bool
    
    /// Check whether the graph contains an edge and whether the node is valid.
    ///
    /// - Returns: `true` if the graph contains the edge.
    ///
    func contains(edge: Edge.ID) -> Bool
    
    /// Get a list of outgoing edges from a node.
    ///
    /// - Parameters:
    ///     - origin: Node from which the edges originate - node is origin
    ///       node of the edge.
    ///
    /// - Returns: List of edges.
    ///
    /// - Complexity: O(n). All edges are traversed in the default implementation.
    ///
    func outgoing(_ origin: Node.ID) -> [Edge]
    
    /// Get a list of edges incoming to a node.
    ///
    /// - Parameters:
    ///     - target: Node to which the edges are incoming – node is a target
    ///       node of the edge.
    ///
    /// - Returns: List of edges.
    ///
    /// - Complexity: O(n). All edges are traversed in the default implementation.
    ///
    func incoming(_ target: Node.ID) -> [Edge]
    
    /// Get a neighbourhood of a node where the edges match the neighbourhood
    /// selector `selector`.
    ///
    func hood(_ nodeID: Node.ID,
              direction: EdgeDirection,
              where edgeMatch: (Edge) -> Bool) -> Neighborhood<Self>
}

extension GraphProtocol {
    public func contains(node: Node.ID) -> Bool {
        return nodes.contains { $0.id == node }
    }
    
    public func contains(edge: Edge.ID) -> Bool {
        return edges.contains { $0.id == edge }
    }
    
    public func node(_ oid: Node.ID) -> Node {
        guard let first: Node = nodes.first(where: { $0.id == oid }) else {
            fatalError("Missing node")
        }
        return first
    }
    
    public func edge(_ oid: Edge.ID) -> Edge {
        guard let first:Edge = edges.first(where: { $0.id == oid }) else {
            fatalError("Missing edge")
        }
        return first
    }
    
    public func outgoing(_ origin: Node.ID) -> [Edge] {
        return self.edges.filter { $0.origin == origin }
    }
    
    public func incoming(_ target: Node.ID) -> [Edge] {
        return self.edges.filter { $0.target == target }
    }
    
    public func hood(_ nodeID: Node.ID,
                     direction: EdgeDirection,
                     where edgeMatch: (Edge) -> Bool) -> Neighborhood<Self> {
        let edges: [Edge]
        switch direction {
        case .incoming: edges = incoming(nodeID)
        case .outgoing: edges = outgoing(nodeID)
        }
        let filtered: [Edge] = edges.filter {
            edgeMatch($0)
        }
        
        return Neighborhood(graph: self,
                            nodeID: nodeID,
                            direction: direction,
                            edges: filtered)
    }
}

/// Collection of nodes connected by edges.
///
public struct Graph<N: Identifiable, E: EdgeProtocol>: GraphProtocol
where E.NodeID == N.ID {
    public typealias Node = N
    public typealias Edge = E

    /// List of nodes.
    public var nodes: [N] = []

    /// List of edges.
    public var edges: [E] = []
    
    /// Create a new graph with given list of nodes and edges.
    public init(nodes: [Node], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
    }
}
