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
public final class StableFrame: Frame, Identifiable {
    public typealias Snapshot = ObjectSnapshot
    
    /// Design to which the frame belongs.
    public unowned let design: Design
    
    /// ID of the frame.
    ///
    /// ID is unique within the design.
    ///
    public let id: EntityID
    
    /// Version snapshots contained in the frame.
    ///
    /// Snapshots might be shared between frames.
    ///
    internal let _snapshots: [ObjectSnapshot]
    @usableFromInline
    internal let _lookup: [ObjectID:ObjectSnapshot]
    @usableFromInline
    internal let _graph: Graph<ObjectID, EdgeObject>
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshots must have referential integrity.
    ///
    init(design: Design, id: FrameID, snapshots: [ObjectSnapshot] = []) {
        // FIXME: [WIP] Rename to init(design:id:unsafeSnapshots:)
        self.design = design
        self.id = id
        self._snapshots = snapshots
        let lookup = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.objectID, $0 ) })
        let nodeKeys = snapshots.compactMap {
            if $0.structure == .node { $0.objectID }
            else { nil }
        }
        let edges: [EdgeObject] = snapshots.compactMap {
            guard case let .edge(originID, targetID) = $0.structure else {
                return nil
            }
            guard let origin = lookup[originID], let target = lookup[targetID] else {
                return nil
            }
            return EdgeObject($0, origin: origin, target: target)
        }
        self._graph = Graph(nodes: nodeKeys, edges: edges)
        self._lookup = lookup
        // FIXME: [WIP] Enable this
//        try! self.validateStructure()
    }
    
    /// Get a list of snapshots.
    ///
    public var snapshots: [ObjectSnapshot] {
        return _snapshots
    }
    
    public var objectIDs: [ObjectID] {
        _snapshots.map { $0.objectID }
    }

    /// Returns `true` if the frame contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _lookup[id] != nil
    }

    public func contained(_ ids: [ObjectID]) -> [ObjectID] {
        ids.filter { _lookup[$0] != nil }
    }

    /// Return an object snapshots with given object ID.
    ///
    /// - Precondition: Frame must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> ObjectSnapshot {
        guard let snapshot = _lookup[id] else {
            preconditionFailure("Invalid object ID \(id) in frame \(self.id)")
        }
        return snapshot
    }
}

