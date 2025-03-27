//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//

/// Protocol for edges in a graph.
///
/// - SeeAlso: ``GraphProtocol``
public protocol EdgeProtocol {
    // TODO: Can we make add Identifiable requirement? Seems like we can.

    associatedtype NodeID: Hashable
    /// Origin of the edge.
    var origin: NodeID { get }
    /// Target of the edge.
    var target: NodeID { get }
}

/// Wrapper of an object snapshot presented as an edge.
///
/// The edge object contains direct references to concrete design objects.
/// The edge object is relevant only within the context of a frame that was used during
/// initialisation.
///
public struct EdgeObject: EdgeProtocol, Identifiable {
    public typealias NodeID = ObjectID

    /// Design object representing the edge
    public let object: DesignObject

    /// ID of the edge design object.
    public var id: ObjectID { object.id }

    /// Reference to the edge origin object extracted from a frame during initialisation.
    public let originObject: DesignObject

    /// ID of the edge origin.
    public var origin: ObjectID { originObject.id }

    /// Reference to the edge target object extracted from a frame during initialisation.
    public let targetObject: DesignObject

    /// ID of the edge target.
    public var target: ObjectID { targetObject.id }

    /// Create a new edge object for a given design object.
    ///
    /// Extracts the edge origin and target object references from the frame based on the
    /// edge endpoints IDs.
    ///
    /// The edge object is relevant only within the context of the frame that was used here, during
    /// the initialisation. It should not be stored or shared.
    ///
    /// If the design object is not an edge, then the initialiser results in `nil`.
    /// 
    public init?(_ snapshot: DesignObject, in frame: some Frame) {
        guard case let .edge(origin, target) = snapshot.structure else {
            return nil
        }

        self.object = snapshot
        self.originObject = frame[origin]
        self.targetObject = frame[target]
    }
}


/// Protocol for object graphs - nodes connected by edges.
///
/// Graphs are used to view interconnected object structures. When you use design frames
/// you will benefit from operations that find neighbourhoods or sort objects topologically.
///
public protocol GraphProtocol {
    /// Type of an unique identifier of a node.
    associatedtype NodeID: Hashable
    /// Object type of a node.
    associatedtype Node
    /// Type of an unique identifier of an edge.
    associatedtype EdgeID: Hashable
    /// Object type of an edge.
    associatedtype Edge: EdgeProtocol where Edge.NodeID == NodeID

    /// Get list of graph's node IDs.
    ///
    var nodeIDs: [NodeID] { get }
    
    /// Get list of graph's edge IDs.
    ///
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
    func edge(_ id: EdgeID) -> Edge
    
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
    public func outgoing(_ origin: NodeID) -> [Edge] {
        return self.edges.filter { $0.origin == origin }
    }
    
    public func incoming(_ target: NodeID) -> [Edge] {
        return self.edges.filter { $0.target == target }
    }
}

extension GraphProtocol where Edge: Identifiable, Edge.ID == EdgeID {
    public func contains(edge: EdgeID) -> Bool {
        return edges.contains { $0.id == edge }
    }

    public func edge(_ oid: EdgeID) -> Edge {
        guard let first:Edge = edges.first(where: { $0.id == oid }) else {
            fatalError("Missing edge")
        }
        return first
    }
}


/// Collection of nodes connected by edges.
///
/// Both nodes and edges are identifiable by the same type.
///
public struct Graph<Node: Identifiable, Edge: EdgeProtocol>: GraphProtocol
where Edge.NodeID == Node.ID, Edge: Identifiable {
    // TODO: Make it a dict
    /// List of nodes.
    public var nodes: [Node] = []

    /// List of edges.
    public var edges: [Edge] = []
    
    /// Create a new graph with given list of nodes and edges.
    public init(nodes: [Node], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var nodeIDs: [NodeID] {
        nodes.map { $0.id }
    }
    
    public var edgeIDs: [EdgeID] {
        edges.map { $0.id }
    }
}
