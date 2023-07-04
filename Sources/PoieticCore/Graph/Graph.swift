//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//


/// Object representing a graph node.
///
/// Graph nodes are objects that can be connected to other nodes with edges.
///
/// - SeeAlso: `Edge`, `Graph`, `MutableGraph`
///
public class Node: ObjectSnapshot {
    public override func derive(snapshotID: SnapshotID,
                                objectID: ObjectID? = nil) -> ObjectSnapshot {
        return Node(id: objectID ?? self.id,
                    snapshotID: snapshotID,
                    type: self.type,
                    components: components.components)
    }
    public override var structuralTypeName: String {
        return "node"
    }

}

/// Edge represents a directed connection between two nodes in a graph.
///
/// The edges in the graph have an origin node and a target node associated
/// with it.
///
/// - SeeAlso: `Node`, `Graph`, `MutableGraph`
public class Edge: ObjectSnapshot {
    public override var structuralTypeName: String {
        return "edge"
    }

    /// Origin node of the edge - a node from which the edge points from.
    ///
    /// Origin is a structural dependency. If the origin node is removed from the
    /// design, then all edges referencing the removed objects will be removed
    /// as well.
    ///
    public var origin: ObjectID {
        willSet {
            precondition(self.state.isMutable)
        }
    }
    /// Target node of the edge - a node to which the edge points to.
    ///
    /// Target is a structural dependency. If the target node is removed from the
    /// design, then all edges referencing the removed objects will be removed
    /// as well.
    ///
    public var target: ObjectID {
        willSet {
            precondition(self.state.isMutable)
        }
    }
    
    /// Create a new edge.
    ///
    /// - Parameters:
    ///     - id: ObjectID of the new edge
    ///     - snapshotID: Snapshot ID (version) of the new edge
    ///     - type: Object type of the edge.
    ///     - origin: An origin node of the edge.
    ///     - target: A target node of the edge.
    ///     - components: List of components to be assigned to the edge.
    ///
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

    /// List of objects that this object depends on. If one of the objects from
    /// the list is removed from the frame, this object must be removed as well.
    ///
    /// For an edge it is the origin node and the target node – if one of those
    /// is removed, the edge is removed with them.
    ///
    override var structuralDependencies: [ObjectID] {
        return [origin, target]
    }

    public override func derive(snapshotID: SnapshotID,
                                objectID: ObjectID? = nil) -> ObjectSnapshot {
        // FIXME: This breaks Edge
        return Edge(id: objectID ?? self.id,
                    snapshotID: snapshotID,
                    type: type,
                    origin: self.origin,
                    target: self.target,
                    components: components.components)
    }
    public override var description: String {
        return "Edge(id: \(id), sshot:\(snapshotID), \(origin) -> \(target), type: \(type?.name ?? "(none)")"
    }

    public override var prettyDescription: String {
        let superDesc = super.prettyDescription

        return superDesc + " \(origin) -> \(target)"
    }

    /// Create a foreign record from the snapshot.
    ///
    public override func foreignRecord() -> ForeignRecord {
        let record = ForeignRecord([
            "object_id": ForeignValue(id),
            "snapshot_id": ForeignValue(snapshotID),
            "structural_type": ForeignValue(structuralTypeName),
            "type": ForeignValue(type?.name ?? "none"),
            "origin": ForeignValue(origin),
            "target": ForeignValue(target),
        ])
        return record
    }

    
}

// TODO: Change node() and edge() to return non-optional
// REASON: ID is rather like an array index than a dictionary key, once we put
// an object into the graph, we usually expect it to be here, if it is not there
// it means that we made a programming error. We are rarely curious about
// the IDs presence in the graph.

/// Protocol for a graph structure.
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
    func selectNodes(_ predicate: NodePredicate) -> [Node]

    /// Get a list of edges that match the given predicate.
    ///
    func selectEdges(_ predicate: EdgePredicate) -> [Edge]

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
    
    public func selectNodes(_ predicate: NodePredicate) -> [Node] {
        return nodes.filter { predicate.match(graph: self, node: $0) }
    }
    public func selectEdges(_ predicate: EdgePredicate) -> [Edge] {
        return edges.filter { predicate.match(graph: self, edge: $0) }
    }
    
    public func hood(_ nodeID: ObjectID, selector: NeighborhoodSelector) -> Neighborhood {
        let edges: [Edge]
        switch selector.direction {
        case .incoming: edges = incoming(nodeID)
        case .outgoing: edges = outgoing(nodeID)
        }
        let filtered: [Edge] = edges.filter {
            selector.predicate.match(graph: self, edge: $0)
        }
        
        return Neighborhood(graph: self,
                            nodeID: nodeID,
                            selector: selector,
                            edges: filtered)
    }
    
    public var prettyDebugDescription: String {
        var result: String = ""
        
        result += "NODES:\n"
        for node in nodes {
            result += "  \(node.id) \(node.type?.name ?? "(no type)")\n"
        }
        result += "EDGES:\n"
        for edge in edges {
            var str: String = ""
            str += "  \(edge.id) \(edge.type?.name ?? "(no type)") "
            + "\(edge.origin) --> \(edge.target)\n"
            result += str
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
public protocol MutableGraph: Graph {
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
    
    
    // Object creation
    @discardableResult
    func createNode(_ type: ObjectType,
                    components: [Component]) -> ObjectID

    @discardableResult
    func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID,
                    components: [Component]) -> ObjectID
}

extension MutableGraph {
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
public class UnboundGraph: Graph {
    let frame: FrameBase
    
    public init(frame: FrameBase) {
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

    public func neighbours(_ node: ObjectID, selector: NeighborhoodSelector) -> [Edge] {
        fatalError("Neighbours of mutable graph not implemented")
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
}


/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
public class MutableUnboundGraph: UnboundGraph, MutableGraph {
    // FIXME: IMPORTANT!: This is a quick hack due to some redesign.
    
    var mutableFrame: MutableFrame {
        self.frame as! MutableFrame
    }
    
    public func insert(_ node: Node) {
        self.mutableFrame.insert(node)
    }
    
    public func insert(_ edge: Edge) {
        self.mutableFrame.insert(edge)
    }
    // Object creation
    public func createEdge(_ type: ObjectType,
                           origin: ObjectID,
                           target: ObjectID,
                           components: [any Component] = []) -> ObjectID {
        precondition(type.structuralType == .edge,
                     "Trying to create an edge using a type '\(type.name)' that has a different structural type: \(type.structuralType)")
        precondition(frame.contains(origin),
                     "Trying to create an edge with unknown origin ID \(origin) in the frame")
        precondition(frame.contains(target),
                     "Trying to create an edge with unknown target ID \(target) in the frame")

        // TODO: This is not very clean: we create a template, then we derive the concrete object.
        // Frame is not aware of structural types, can only create plain objects.
        // See file Documentation/ObjectCreation.md for more discussion.
        let object = Edge(id:0,
                          snapshotID:0,
                          type: type,
                          origin: origin,
                          target: target,
                          components: components)
        for componentType in type.components {
            if !object.components.has(componentType) {
                object.components.set(componentType.init())
            }
        }
        
        let derived = mutableFrame.insertDerived(object)
        return derived
    }
    public func createNode(_ type: ObjectType,
                           components: [any Component] = []) -> ObjectID {
        precondition(type.structuralType == .node,
                     "Trying to create a node using a type '\(type.name)' that has a different structural type: \(type.structuralType)")

        // TODO: This is not very clean: we create a template, then we derive the concrete object.
        // Frame is not aware of structural types, can only create plain objects.
        // See file Documentation/ObjectCreation.md for more discussion.
        let object = Node(id:0,
                          snapshotID:0,
                          type: type,
                          components: components)
        for componentType in type.components {
            if !object.components.has(componentType) {
                object.components.set(componentType.init())
            }
        }
        
        return mutableFrame.insertDerived(object)
    }

    public func remove(node nodeID: ObjectID) {
        self.mutableFrame.removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        self.mutableFrame.removeCascading(edgeID)
    }
}
