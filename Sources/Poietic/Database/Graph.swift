//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/06/2023.
//

public class EdgePredicate {
    init() {
        fatalError("Edge Predicate is not implemented")
    }
}

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

public struct EdgeSelector {
    public let direction: EdgeDirection
    public let predicate: EdgePredicate
}

public class Node: ObjectSnapshot {
    public override func derive(snapshotID: SnapshotID,
                       objectID: ObjectID? = nil) -> ObjectSnapshot {
        return Node(id: objectID ?? self.id,
                    snapshotID: snapshotID,
                    type: self.type,
                    components: components.components)
    }

}

public class Edge: ObjectSnapshot {
    public var origin: ObjectID {
        willSet {
            precondition(self.state.isMutable)
        }
    }
    public var target: ObjectID {
        willSet {
            precondition(self.state.isMutable)
        }
    }
    
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType? = nil,
                origin: ObjectID,
                target: ObjectID,
                components: [any Component] = []) {
        self.origin = origin
        self.target = target
        super.init(id: id,
                   snapshotID: snapshotID,
                   type: type,
                   components: components)
    }

    public override func derive(snapshotID: SnapshotID,
                       objectID: ObjectID? = nil) -> ObjectSnapshot {
        // FIXME: This breaks Edge
        return Edge(id: objectID ?? self.id,
                    snapshotID: snapshotID,
                    origin: self.origin,
                    target: self.target,
                    components: components.components)
    }

}


public protocol GraphProtocol {
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
    func node(_ index: ObjectID) -> Node?

    /// Get an edge by ID.
    ///
    func edge(_ index: ObjectID) -> Edge?

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
    ///   then use ``neighbours(_:)-d13k``. Using ``outgoing(_:)`` + ``incoming(_:)-3rfqk`` might
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
    ///   then use ``neighbours``. Using ``outgoing`` + ``incoming`` might
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
    
    /// Returns edges that are related to the node and that match the given
    /// edge selector.
    ///
    func neighbours(_ node: ObjectID, selector: EdgeSelector) -> [Edge]

}

extension GraphProtocol {
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
    public func node(_ oid: ObjectID) -> Node? {
        return nodes.first { $0.id == oid }
    }

    /// Get an edge by ID.
    ///
    /// If id is `nil` then returns nil.
    ///
    public func edge(_ oid: ObjectID) -> Edge? {
        return edges.first { $0.id == oid }
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
    
//    public func neighbours(_ node: NodeID, selector: EdgeSelector) -> [Edge] {
//        let edges: [Edge]
//        switch selector.direction {
//        case .incoming: edges = self.incoming(node)
//        case .outgoing: edges = self.outgoing(node)
//        }
//
//        return edges.filter { $0.contains(labels: selector.labels) }
//    }

}


/// Protocol
public protocol MutableGraphProtocol: GraphProtocol {
    /// Remove all nodes and edges from the graph.
    func removeAll()
    
    /// Add a node to the graph.
    ///
    func insert(_ node: Node)

    /// Add an edge to the graph.
    ///
    func insert(_ edge: Edge)

    /// Remove a node from the graph and return a list of edges that were
    /// removed together with the node.
    ///
    func remove(node nodeID: ObjectID)
    
    /// Remove an edge from the graph.
    ///
    func remove(edge edgeID: ObjectID)
}

extension MutableGraphProtocol {
    public func removeAll() {
        for edge in edgeIDs {
            remove(edge: edge)
        }
        for node in nodeIDs {
            remove(node: node)
        }
    }

}

/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
public class MutableUnboudGraph: MutableGraphProtocol {
    public func neighbours(_ node: ObjectID, selector: EdgeSelector) -> [Edge] {
        fatalError("Neighbours of mutable graph not implemented")
    }
    
    public func insert(_ node: Node) {
        self.frame.insert(node)
    }
    
    public func insert(_ edge: Edge) {
        self.frame.insert(edge)
    }
    
    public func remove(node nodeID: ObjectID) {
        self.frame.removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        self.frame.removeCascading(edgeID)
    }
    
    public var nodes: [Node] {
        return self.frame.snapshots.compactMap {
            $0 as? Node
        }
    }
    
    public var edges: [Edge] {
        return self.frame.snapshots.compactMap {
            $0 as? Edge
        }
    }
    
    let frame: MutableFrame
    
    public init(frame: MutableFrame) {
        self.frame = frame
    }
    
    /// Get a node by ID.
    ///
    public func node(_ index: ObjectID) -> Node? {
        return self.frame.object(index) as? Node
    }

    /// Get an edge by ID.
    ///
    public func edge(_ index: ObjectID) -> Edge? {
        return self.frame.object(index) as? Edge
    }

    public func contains(node: ObjectID) -> Bool {
        return self.node(node) != nil
    }

    public func contains(edge: ObjectID) -> Bool {
        return self.edge(edge) != nil
    }

    
}
