//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//

// FIXME: [REFACTORING] In Compiler.initialize():
// FIXME: [REFACTORING] Frame.filterEdges
// FIXME: [REFACTORING] View.simulationNodes
// FIXME: [REFACTORING] View.flowEdges: [EdgeSnapshot<DesignObject>] {

/**
 Edge types:
 
 (object: object -> object)
 (some: id -> id)
 
 
 */

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

// DesignObject DesignEdge
public struct _ReferenceEdge: EdgeProtocol {
    public typealias ID = ObjectID
    public let id: ObjectID
    public let origin: ObjectID
    public let target: ObjectID
}

public struct SnapshotEdge: EdgeProtocol {
    public typealias ID = ObjectID
    public let object: DesignObject
    public let origin: DesignObject
    public let target: DesignObject

    public var id: ObjectID { object.id }
}

/// Protocol for object graphs - nodes connected by edges.
///
/// Graphs are used to view interconnected object structures. When you use design frames
/// you will benefit from operations that find neighbourhoods or sort objects topologically.
///
public protocol GraphProtocol {
    associatedtype NodeID: Hashable
    associatedtype Node
    associatedtype EdgeID: Hashable
    associatedtype Edge: EdgeProtocol where Edge.ID == EdgeID, Edge.NodeID == NodeID

    var nodeIDs: [NodeID] { get }
    
    var edgeIDs: [EdgeID] { get }

    /// All nodes of the graph
    var nodes: [Node] { get }
    
    /// All edges of the graph
    var edges: [Edge] { get }
    
    /// Get a node by ID.
    ///
    /// - Precondition: The graph must contain the node.
    ///
    func node(_ id: NodeID) -> Node
    
    /// Get an edge by ID.
    ///
    /// - Precondition: The graph must contain the edge.
    ///
    func edge(_ id: Edge.ID) -> Edge
    
    /// Check whether the graph contains a node object with given ID.
    ///
    /// - Returns: `true` if the graph contains the node.
    ///
    func contains(node: NodeID) -> Bool
    
    /// Check whether the graph contains an edge and whether the node is valid.
    ///
    /// - Returns: `true` if the graph contains the edge.
    ///
    func contains(edge: EdgeID) -> Bool
    
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
    func outgoing(_ origin: NodeID) -> [Edge]
    
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
    func incoming(_ target: NodeID) -> [Edge]
    
    /// Get a neighbourhood of a node where the edges match the neighbourhood
    /// selector `selector`.
    ///
    func hood(_ nodeID: NodeID,
              direction: EdgeDirection,
              where edgeMatch: (Edge) -> Bool) -> Neighborhood<Self>
}

extension GraphProtocol where Node: Identifiable<NodeID> {
    public func contains(node: NodeID) -> Bool {
        return nodes.contains { $0.id == node }
    }
    
    public func node(_ oid: NodeID) -> Node {
        guard let first: Node = nodes.first(where: { $0.id == oid }) else {
            fatalError("Missing node")
        }
        return first
    }
}
extension GraphProtocol {
    public func contains(edge: EdgeID) -> Bool {
        return edges.contains { $0.id == edge }
    }
    
    public func edge(_ oid: Edge.ID) -> Edge {
        guard let first:Edge = edges.first(where: { $0.id == oid }) else {
            fatalError("Missing edge")
        }
        return first
    }
    
    public func outgoing(_ origin: NodeID) -> [Edge] {
        return self.edges.filter { $0.origin == origin }
    }
    
    public func incoming(_ target: NodeID) -> [Edge] {
        return self.edges.filter { $0.target == target }
    }
    
    public func hood(_ nodeID: NodeID,
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
    public var nodeIDs: [NodeID] {
        nodes.map { $0.id }
    }
    
    public var edgeIDs: [EdgeID] {
        edges.map { $0.id }
    }

    public typealias Node = N
    public typealias NodeID = N.ID
    public typealias Edge = E
    public typealias EdgeID = E.ID

    /// List of nodes.
    public var nodes: [Node] = []

    /// List of edges.
    public var edges: [Edge] = []
    
    /// Create a new graph with given list of nodes and edges.
    public init(nodes: [Node], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
    }
}
