//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//

/// View of an object as a graph node.
///
/// Graph nodes are objects that can be connected to other nodes with edges.
///
/// - SeeAlso: `Edge`, `Graph`, `MutableGraph`
///
public struct Node {
    /// Object snapshot that represents the node.
    ///
    public let snapshot: any ObjectSnapshot
    
    
    /// Create a new node view from a snapshot.
    ///
    ///
    public init?(_ snapshot: any ObjectSnapshot) {
        guard snapshot.structure.type == .node else {
            return nil
        }
        self.snapshot = snapshot
    }
    
}

extension Node {
    public var id: ObjectID { snapshot.id }
    public var type: ObjectType { snapshot.type }
    public var name: String? { snapshot.name }
}

/// View of an object as an edge.
///
public struct Edge {
    public let snapshot: any ObjectSnapshot
    public let origin: ObjectID
    public let target: ObjectID
    
    public init?(_ snapshot: any ObjectSnapshot) {
        guard case let .edge(origin, target) = snapshot.structure else {
            return nil
        }

        self.snapshot = snapshot
        self.origin = origin
        self.target = target
    }
}

extension Edge {
    public var id: ObjectID { snapshot.id }
    public var type: ObjectType { snapshot.type }
    public var name: String? { snapshot.name }
}


/// Protocol for views of a frame as a graph.
///
/// You can access the graph-related contents of the frame through the
/// graph view. The view gives access to objects of structural type ``StructuralType/node``
/// and ``StructuralType/edge`` for nodes and edges respectively. Objects
/// of other structural types are ignored.
///
public protocol Graph {
    /// List of indices of all nodes
    var nodeIDs: [ObjectID] { get }

    /// List of indices of all edges
    var edgeIDs: [ObjectID] { get }
    
    /// All nodes of the graph
    var nodes: [Node] { get }
    
    /// All edges of the graph
    var edges: [Edge] { get }

    /// Get a node by ID.
    ///
    func node(_ index: ObjectID) -> Node

    /// Get an edge by ID.
    ///
    func edge(_ index: ObjectID) -> Edge

    /// Check whether the graph contains a node and whether the node is valid.
    ///
    /// - Returns: `true` if the graph contains the node.
    ///
    /// - Note: Node comparison is based on its identity. Two nodes with the
    /// same attributes that are equatable are considered distinct nodes in the
    /// graph.
    ///
    ///
    func contains(node: ObjectID) -> Bool
    
    /// Check whether the graph contains an edge and whether the node is valid.
    ///
    /// - Returns: `true` if the graph contains the edge.
    ///
    /// - Note: Edge comparison is based on its identity.
    ///
    func contains(edge: ObjectID) -> Bool

    /// Get a list of outgoing edges from a node.
    ///
    /// - Parameters:
    ///     - origin: Node from which the edges originate - node is origin
    ///     node of the edge.
    ///
    /// - Returns: List of edges.
    ///
    /// - Complexity: O(n). All edges are traversed.
    ///
    /// - Note: If you want to get both outgoing and incoming edges of a node
    ///   then use ``neighbours(_:)``. Using ``outgoing(_:)`` + ``incoming(_:)`` might
    ///   result in duplicates for edges that are loops to and from the same
    ///   node.
    ///
    func outgoing(_ origin: ObjectID) -> [Edge]
    
    /// Get a list of edges incoming to a node.
    ///
    /// - Parameters:
    ///     - target: Node to which the edges are incoming – node is a target
    ///       node of the edge.
    ///
    /// - Returns: List of edges.
    ///
    /// - Complexity: O(n). All edges are traversed.
    ///
    /// - Note: If you want to get both outgoing and incoming edges of a node
    ///   then use ``neighbours(_:)``. Using ``outgoing(_:)`` + ``incoming(_:)`` might
    ///   result in duplicates for edges that are loops to and from the same
    ///   node.
    ///

    func incoming(_ target: ObjectID) -> [Edge]
    
    /// Get a list of edges that are related to the neighbours of the node. That
    /// is, list of edges where the node is either an origin or a target.
    ///
    /// - Returns: List of edges.
    ///
    /// - Complexity: O(n). All edges are traversed.
    ///
    func neighbours(_ node: ObjectID) -> [Edge]
    
    /// Get a list of nodes that match the given predicate.
    ///
    func selectNodes(_ predicate: Predicate) -> [Node]

    /// Get a list of edges that match the given predicate.
    ///
    func selectEdges(_ predicate: Predicate) -> [Edge]

    /// Get a neighbourhood of a node where the edges match the neighbourhood
    /// selector `selector`.
    ///
    func hood(_ nodeID: ObjectID, selector: NeighborhoodSelector) -> Neighborhood
}

extension Graph {
    public var nodeIDs: [ObjectID] {
        nodes.map { $0.id }
    }

    public var edgeIDs: [ObjectID] {
        edges.map { $0.id }
    }

    public func contains(node: ObjectID) -> Bool {
        return nodeIDs.contains { $0 == node }
    }

    public func contains(edge: ObjectID) -> Bool {
        return edgeIDs.contains { $0 == edge }
    }
    
    /// Get a node by ID.
    ///
    /// If id is `nil` then returns nil.
    ///
    public func node(_ oid: ObjectID) -> Node {
        guard let first: Node = nodes.first(where: { $0.id == oid }) else {
            fatalError("Missing node")
        }
        return first
    }

    /// Get an edge by ID.
    ///
    /// If id is `nil` then returns nil.
    ///
    public func edge(_ oid: ObjectID) -> Edge {
        guard let first:Edge = edges.first(where: { $0.id == oid }) else {
            fatalError("Missing edge")
        }
        return first
    }

    public func outgoing(_ origin: ObjectID) -> [Edge] {
        let result: [Edge]
        
        result = self.edges.filter {
            $0.origin == origin
        }

        return result
    }
    
    public func incoming(_ target: ObjectID) -> [Edge] {
        let result: [Edge]
        
        result = self.edges.filter {
            $0.target == target
        }

        return result
    }
    
    public func neighbours(_ node: ObjectID) -> [Edge] {
        let result: [Edge]
        
        result = self.edges.filter {
            $0.target == node || $0.origin == node
        }

        return result
    }
        
    public var prettyDebugDescription: String {
        var result: String = ""
        
        result += "NODES:\n"
        for node in nodes {
            result += "  \(node.id) \(node.type.name)\n"
        }
        result += "EDGES:\n"
        for edge in edges {
            var str: String = ""
            str += "  \(edge.id) \(edge.type.name) "
            + "\(edge.origin) --> \(edge.target)\n"
            result += str
        }
        return result
    }
}
