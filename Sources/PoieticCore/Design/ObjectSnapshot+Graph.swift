//
//  StableFrame+Graph.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/05/2025.
//

/*
 
 Graph uses:
 
 edges type == parameter
 edges type == parameter && target trait formula
 node type == chart
 node on edge == chart series
 frame first: trait simulation
 view simulation nodes (custom filter)
 view incoming parameter nodes (incoming + type)
 view drains/fills (incoming/outgoing + type)
 frame type stock
 
 incoming/outgoing + type
 edge of type
 edge of custom filter
 edge of trait
 node of trait
 node of type

 */

extension DesignFrame /* : GraphProtocol */ {
    @inlinable
    public var nodeKeys: [ObjectID] { _graph.nodeKeys }
    @inlinable
    public var edgeKeys: [ObjectID] { _graph.edgeKeys }

    public var nodes: [ObjectSnapshot] {
        _graph.nodeKeys.map { _lookup[$0]! }
    }

    public func nodes(type: ObjectType) -> [ObjectSnapshot] {
        _graph.nodeKeys.compactMap {
            guard let node = _lookup[$0], node.type === type else {
                return nil
            }
            return node
        }
    }
    public func nodes(withTrait trait: Trait) -> [ObjectSnapshot] {
        _graph.nodeKeys.compactMap {
            guard let node = _lookup[$0], node.type.hasTrait(trait) else {
                return nil
            }
            return node
        }
    }

    public var edges: [Edge] { _graph.edges }

    public func edges(type: ObjectType) -> [Edge] {
        _graph.edges.filter {
            $0.object.type === type
        }
    }
    public func edges(withTrait trait: Trait) -> [Edge] {
        _graph.edges.compactMap {
            guard $0.object.type.hasTrait(trait) else {
                return nil
            }
            return $0
        }
    }

    @inlinable
    public func contains(node: NodeKey) -> Bool {
        return _graph.contains(node: node)
    }

    public func node(_ oid: NodeKey) -> ObjectSnapshot {
        guard let snapshot = _lookup[oid] else {
            fatalError("Missing node: \(oid)")
        }
        guard snapshot.structure == .node else {
            fatalError("Not a node: \(oid)")
        }
        return snapshot
    }

    public func contains(edge: ObjectID) -> Bool {
        return _graph.contains(edge: edge)
    }

    public func edge(_ oid: EdgeKey) -> Edge {
        guard let snapshot = _lookup[oid] else {
            fatalError("Missing edge: \(oid)")
        }
        guard let edge = DesignObjectEdge(snapshot, in: self) else {
            fatalError("Not an edge: \(oid)")
        }
        return edge
    }
    public func outgoing(_ origin: NodeKey) -> [Edge] {
        return _graph.outgoing(origin)
    }
    
    public func incoming(_ target: NodeKey) -> [Edge] {
        return _graph.incoming(target)
    }

}
