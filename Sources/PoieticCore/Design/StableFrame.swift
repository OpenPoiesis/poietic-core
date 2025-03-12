//
//  StableFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//

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
    private(set) internal var _snapshots: [ObjectID:DesignObject]
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshot must not be mutable.
    ///
    init(design: Design, id: FrameID, snapshots: [DesignObject]? = nil) {
        self.design = design
        self.id = id
        self._snapshots = [:]
        
        if let snapshots {
            for snapshot in snapshots {
                self._snapshots[snapshot.id] = snapshot
            }
        }
    }
    
    /// Get a list of snapshots.
    ///
    public var snapshots: [DesignObject] {
        return Array(_snapshots.values)
    }
    
    /// Returns `true` if the frame contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _snapshots[id] != nil
    }

    public func contains(_ snapshot: DesignObject) -> Bool {
        return _snapshots[snapshot.id] === snapshot
    }

    public func contained(_ ids: [ObjectID]) -> [ObjectID] {
        ids.filter { _snapshots[$0] != nil }
    }

    /// Return an object snapshots with given object ID.
    ///
    /// - Precondition: Frame must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> DesignObject {
        guard let snapshot = _snapshots[id] else {
            preconditionFailure("Invalid object ID \(id) in frame \(self.id)")
        }
        return snapshot
    }
    
    // MARK: - Graph Protocol
    public var edgeIDs: [ObjectID] {
        _snapshots.values.compactMap {
            $0.structure.type == .edge ? $0.id : nil
        }
    }

    public func contains(node: NodeID) -> Bool {
        guard let snapshot = _snapshots[id] else {
            return false
        }
        return snapshot.structure == .node
    }

    public func node(_ oid: NodeID) -> Node {
        guard let snapshot = _snapshots[id] else {
            fatalError("Missing node: \(oid)")
        }
        guard snapshot.structure == .node else {
            fatalError("Not a node: \(oid)")
        }
        return snapshot
    }

    public func contains(edge: EdgeID) -> Bool {
        guard let snapshot = _snapshots[id] else {
            return false
        }
        return snapshot.structure.type == .edge
    }

    public func edge(_ oid: EdgeID) -> Edge {
        guard let snapshot = _snapshots[oid] else {
            fatalError("Missing edge: \(oid)")
        }
        guard let edge = EdgeObject(snapshot, in: self) else {
            fatalError("Not an edge: \(oid)")
        }
        return edge
    }
    // TODO: add outgoing(...)
    // TODO: add incoming(...)
}
