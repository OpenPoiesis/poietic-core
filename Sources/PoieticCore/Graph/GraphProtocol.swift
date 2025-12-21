//
//  Graph.swift
//
//
//  Created by Stefan Urbanek on 04/06/2023.
//

/// Wrapper of an object snapshot presented as an edge.
///
/// The edge object contains direct references to concrete design objects.
/// The edge object is relevant only within the context of a frame that was used during
/// initialisation.
///
public struct DesignObjectEdge: EdgeProtocol {
    public typealias NodeKey = ObjectID
    public typealias EdgeKey = ObjectID

    /// Design object representing the edge
    public let object: ObjectSnapshot
    
    /// ID of the edge design object.
    public var id: ObjectID { object.objectID }
    
    /// Reference to the edge origin object extracted from a frame during initialisation.
    public let originObject: ObjectSnapshot
    
    /// ID of the edge origin.
    public var origin: ObjectID { originObject.objectID }
    
    /// Reference to the edge target object extracted from a frame during initialisation.
    public let targetObject: ObjectSnapshot
    
    /// ID of the edge target.
    public var target: ObjectID { targetObject.objectID }
    
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
    public init?(_ snapshot: ObjectSnapshot, in frame: some Frame) {
        guard case let .edge(originID, targetID) = snapshot.structure,
                let origin = frame[originID],
                let target = frame[targetID]
        else {
            return nil
        }
        
        self.object = snapshot
        self.originObject = origin
        self.targetObject = target
    }
    internal init(_ snapshot: ObjectSnapshot, origin: ObjectSnapshot, target: ObjectSnapshot) {
        precondition(snapshot.structure == .edge(origin.objectID, target.objectID))
        
        self.object = snapshot
        self.originObject = origin
        self.targetObject = target
    }

}

/// Protocol for edges in a graph.
///
/// - SeeAlso: ``GraphProtocol``
public protocol EdgeProtocol {
    // TODO: Can we make add Identifiable requirement? Seems like we can.

    associatedtype EdgeKey: Hashable
    associatedtype NodeKey: Hashable
    var id: EdgeKey { get }
    /// Origin of the edge.
    var origin: NodeKey { get }
    /// Target of the edge.
    var target: NodeKey { get }
}




/// Protocol for object graphs - nodes connected by edges.
///
/// Graphs are used to view interconnected object structures. When you use design frames
/// you will benefit from operations that find neighbourhoods or sort objects topologically.
///
public protocol GraphProtocol {
    /// Type of an unique identifier of a node.
    associatedtype NodeKey: Hashable
    associatedtype EdgeKey: Hashable
    associatedtype Edge: EdgeProtocol where Edge.NodeKey == NodeKey, Edge.EdgeKey == EdgeKey
    
    /// Get list of graph's node IDs.
    ///
    var nodeKeys: [NodeKey] { get }
    
    /// Get list of graph's edge IDs.
    ///
    var edgeKeys: [EdgeKey] { get }
    
    var edges: [Edge] { get }
    
    /// Check whether the graph contains a node object with given ID.
    ///
    /// - Returns: `true` if the graph contains the node.
    ///
    func contains(node: NodeKey) -> Bool
    
    /// Check whether the graph contains an edge and whether the node is valid.
    ///
    /// - Returns: `true` if the graph contains the edge.
    ///
    func contains(edge: EdgeKey) -> Bool
    
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
    func outgoing(_ origin: NodeKey) -> [Edge]
    
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
    func incoming(_ target: NodeKey) -> [Edge]

}

extension GraphProtocol {
    public func contains(node: NodeKey) -> Bool {
        return nodeKeys.contains(node)
    }
    
    public func contains(edge: EdgeKey) -> Bool {
        return edgeKeys.contains(edge)
    }

    public func edge(_ key: EdgeKey) -> Edge? {
        return edges.first { $0.id == key }
    }

    public func outgoing(_ origin: NodeKey) -> [Edge] {
        return edges.filter { $0.origin == origin }
    }
    
    public func incoming(_ target: NodeKey) -> [Edge] {
        return edges.filter { $0.target == target }
    }
    
    
}

public protocol PropertyGraphProtocol: GraphProtocol {
    associatedtype NodeProperty
    associatedtype EdgeProperty
    /// Get a node by ID.
    ///
    /// - Precondition: The graph must contain the node.
    ///
    func nodeProperty(_ id: NodeKey) -> NodeProperty
    
    /// Get an edge by ID.
    ///
    /// - Precondition: The graph must contain the edge.
    ///
    func edgeProperty(_ id: EdgeKey) -> EdgeProperty
}

//extension PropertyGraphProtocol {
//    public func node(_ oid: NodeID) -> Node {
//        guard let first: Node = nodes.first(where: { $0.id == oid }) else {
//            fatalError("Missing node")
//        }
//        return first
//    }
//}
