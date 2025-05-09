//
//  StableFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//

// TODO: [WIP] [NOTE] Does not have to have referential integrity
/// Design frame that has been accepted and can not be changed.
///
/// The stable frame is a collection of object versions that together represent
/// a version snapshot of a design. The frame is immutable.
///
/// Stable frames can not be created directly. They can be created only from
/// mutable frames through validation using ``Design/accept(_:appendHistory:)``.
///
/// To create a derivative frame from a stable frame use
/// ``Design/createFrame(deriving:id:)``.
///
/// - SeeAlso: ``TransientFrame``
///
public final class DesignFrame: Frame {
    public typealias Snapshot = DesignObject
    
    /// Design to which the frame belongs.
    public unowned let design: Design
    
    /// ID of the frame.
    ///
    /// ID is unique within the design.
    ///
    public let id: FrameID
    
    /// Version snapshots contained in the frame.
    ///
    /// Snapshots might be shared between frames.
    ///
    private let _snapshots: [DesignObject]
    internal let _index: _FrameIndex
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshots must have referential integrity.
    ///
    init(design: Design, id: FrameID, snapshots: [DesignObject] = []) {
        self.design = design
        self.id = id
        self._index = _FrameIndex(snapshots)
        self._snapshots = snapshots
    }
    
    /// Get a list of snapshots.
    ///
    public var snapshots: [DesignObject] {
        return _snapshots
    }
    
    /// Returns `true` if the frame contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _index.idMap[id] != nil
    }

    public func contains(_ snapshot: DesignObject) -> Bool {
        return _index.idMap[snapshot.id] === snapshot
    }

    public func contained(_ ids: [ObjectID]) -> [ObjectID] {
        ids.filter { _index.idMap[$0] != nil }
    }

    /// Return an object snapshots with given object ID.
    ///
    /// - Precondition: Frame must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> DesignObject {
        guard let snapshot = _index.idMap[id] else {
            preconditionFailure("Invalid object ID \(id) in frame \(self.id)")
        }
        return snapshot
    }
    
    // MARK: - Graph Protocol
    public var nodeIDs: [ObjectID] {
        _index.nodeIDs
    }
    public var nodes: [Node] {
        return _index.nodes
    }
    public var edges: [Edge] {
        return _index.edges
    }

    public var edgeIDs: [ObjectID] {
        _index.edgeIDs
    }

    public func contains(node: NodeID) -> Bool {
        return _index.nodeIDs.contains(node)
    }

    public func node(_ oid: NodeID) -> Node {
        guard let snapshot = _index.idMap[id] else {
            fatalError("Missing node: \(oid)")
        }
        guard snapshot.structure == .node else {
            fatalError("Not a node: \(oid)")
        }
        return snapshot
    }

    public func contains(edge: ObjectID) -> Bool {
        return _index.edgeIDs.contains(edge)
    }

    public func edge(_ oid: EdgeID) -> Edge {
        guard let snapshot = _index.idMap[oid] else {
            fatalError("Missing edge: \(oid)")
        }
        guard let edge = EdgeObject(snapshot, in: self) else {
            fatalError("Not an edge: \(oid)")
        }
        return edge
    }
    public func outgoing(_ origin: NodeID) -> [Edge] {
        return _index.outgoingEdges[origin] ?? []
    }
    
    public func incoming(_ target: NodeID) -> [Edge] {
        return _index.incomingEdges[target] ?? []
    }
}

