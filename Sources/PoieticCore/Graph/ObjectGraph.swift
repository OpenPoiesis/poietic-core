//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//

/// View of an object as an edge.
///
public struct EdgeSnapshot: EdgeProtocol {
    // FIXME: [WIP] Clean-up the types
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

    public var id: ObjectID { snapshot.id }
    public var type: ObjectType { snapshot.type }
    public var name: String? { snapshot.name }
}

/// Protocol for edges in a graph.
///
/// - SeeAlso: ``ObjectGraph``
public protocol EdgeProtocol: Identifiable where ID == ObjectID {
    /// Origin of the edge.
    var origin: ObjectID { get }
    /// Target of the edge.
    var target: ObjectID { get }
}


/// Collection of objects as nodes and edges.
///
/// Graphs are used to view interconnected object structures. When you use design frames
/// you will benefit from operations that find neighbourhoods or sort objects topologically.
///
public protocol ObjectGraph {
    associatedtype Node: ObjectSnapshot
    associatedtype Edge: EdgeProtocol
    
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
    
    /// Check whether the graph contains a node object with given ID.
    ///
    /// - Returns: `true` if the graph contains the node.
    ///
    func contains(node: ObjectID) -> Bool
    
    /// Check whether the graph contains an edge and whether the node is valid.
    ///
    /// - Returns: `true` if the graph contains the edge.
    ///
    func contains(edge: ObjectID) -> Bool
    
    /// Get a list of outgoing edges from a node.
    ///
    /// - Parameters:
    ///     - origin: Node from which the edges originate - node is origin
    ///       node of the edge.
    ///
    /// - Returns: List of edges.
    ///
    /// - Complexity: O(n) for the default implementation – all edges are traversed.
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
    
    /// Get a neighbourhood of a node where the edges match the neighbourhood
    /// selector `selector`.
    ///
    func hood(_ nodeID: ObjectID, selector: NeighborhoodSelector) -> Neighborhood<Self>
}

extension ObjectGraph {
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
        return self.edges.filter { $0.origin == origin }
    }
    
    public func incoming(_ target: ObjectID) -> [Edge] {
        return self.edges.filter { $0.target == target }
    }
    
    public func neighbours(_ node: ObjectID) -> [Edge] {
        let result: [Edge]
        
        result = self.edges.filter {
            $0.target == node || $0.origin == node
        }

        return result
    }
}
