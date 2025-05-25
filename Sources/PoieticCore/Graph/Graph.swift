//
//  Graph.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/05/2025.
//


/// Immutable graph structure.
///
/// - Note: Optimised for look-ups. Can be considered as graph-structure index.
///
public class Graph<NK: Hashable, E: EdgeProtocol>: GraphProtocol
where E.NodeKey == NK {
    public typealias NodeKey = NK
    public typealias EdgeKey = E.EdgeKey
    public typealias Edge = E

    /// key: node, value: edge where origin == node
    internal let outgoingEdges: [NodeKey:[Edge]]
    /// key: node, value: edge where target == node
    internal let incomingEdges: [NodeKey:[Edge]]
    internal let _nodeKeys: Set<NodeKey>
    internal let _edgeKeys: Set<EdgeKey>
    internal let edgeMap: [EdgeKey:Edge]

    public var nodeKeys: [NodeKey] { Array(_nodeKeys) }
    public var edgeKeys: [EdgeKey] { Array(_edgeKeys) }
    public let edges: [Edge]

    /// Create a new graph with given node keys and edges.
    ///
    /// - SeeAlso: ``EdgeProtocol``.
    ///
    public init(nodes: [NodeKey], edges: [Edge]) {
        var outgoingEdges: [NodeKey:[Edge]] = [:]
        var incomingEdges: [NodeKey:[Edge]] = [:]
        var edgeKeys: Set<EdgeKey> = []
        var edgeMap: [EdgeKey:Edge] = [:]

        self._nodeKeys = Set(nodes)

        for edge in edges {
            edgeKeys.insert(edge.key)
            outgoingEdges[edge.origin, default: []].append(edge)
            incomingEdges[edge.target, default: []].append(edge)
            edgeMap[edge.key] = edge
        }
        
        self._edgeKeys = edgeKeys
        self.outgoingEdges = outgoingEdges
        self.incomingEdges = incomingEdges
        self.edges = edges
        self.edgeMap = edgeMap
    }
    
    public func contains(node: NodeKey) -> Bool {
        return _nodeKeys.contains(node)
    }
    public func contains(edge: EdgeKey) -> Bool {
        return _edgeKeys.contains(edge)
    }
    public func outgoing(_ origin: NodeKey) -> [Edge] {
        outgoingEdges[origin] ?? []
    }
    public func incoming(_ target: NodeKey) -> [Edge] {
        incomingEdges[target] ?? []
    }
    public func edge(_ key: EdgeKey) -> Edge? {
        return edgeMap[key]
    }
}

protocol GraphItemProtocol {
    associatedtype GraphItemKey: Hashable
    associatedtype GraphItem
    var graphItemKey: GraphItemKey { get }
    var graphItem: GraphItem { get }
}

protocol GraphEdgeProtocol: GraphItemProtocol {
    associatedtype GraphNodeKey: Hashable
    var origin: GraphNodeKey { get }
    var target: GraphNodeKey { get }
}

class PropertyGraphView<N: GraphItemProtocol, E: GraphItemProtocol> {
    typealias NodeType = N
    typealias EdgeType = E
    typealias NodeKey = N.GraphItemKey
    typealias EdgeKey = E.GraphItemKey
    typealias NodeItem = N.GraphItem
    typealias EdgeItem = E.GraphItem
    struct Edge {
        let key: EdgeKey
        let origin: NodeKey
        let target: NodeKey
        let item: EdgeItem
    }
    /// key: node, value: edge where origin == node
    internal let outgoingEdges: [NodeKey:[Edge]]
    /// key: node, value: edge where target == node
    internal let incomingEdges: [NodeKey:[Edge]]
    internal let nodeKeys: Set<NodeKey>
    internal let edgeKeys: Set<EdgeKey>
    internal let nodeItems: [NodeItem]
    internal let edgeItems: [EdgeItem]
    internal let edges: [Edge]

    init(nodes: [NodeType], edges: [Edge]) {
        var outgoingEdges: [NodeKey:[Edge]] = [:]
        var incomingEdges: [NodeKey:[Edge]] = [:]
        var nodeItems: [NodeItem] = []
        var nodeKeys: Set<NodeKey> = Set()
        var edgeItems: [EdgeItem] = []
        var edgeKeys: Set<EdgeKey> = Set()
        var _edges: [Edge] = []

        for node in nodes {
            nodeItems.append(node.graphItem)
            nodeKeys.insert(node.graphItemKey)
        }
        self.nodeKeys = nodeKeys
        self.nodeItems = nodeItems
        
        for edge in edges {
            _edges.append(edge)
            edgeItems.append(edge.item)
            edgeKeys.insert(edge.key)
            outgoingEdges[edge.origin, default: []].append(edge)
            incomingEdges[edge.target, default: []].append(edge)
        }
        
        self.edgeKeys = edgeKeys
        self.edgeItems = edgeItems
        self.outgoingEdges = outgoingEdges
        self.incomingEdges = incomingEdges
        self.edges = _edges
    }
}
