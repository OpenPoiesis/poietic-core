//
//  StableFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//

/// Stable design frame that can not be mutated.
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
public final class StableFrame: Frame {
    public typealias Snapshot = StableObject
    
    /// Design to which the frame belongs.
    public unowned let design: Design
    
    /// ID of the frame.
    ///
    /// ID is unique within the design.
    ///
    public let id: FrameID
    
    /// Versions of objects in the plane.
    ///
    /// Objects not in the map do not exist in the version plane, but might
    /// exist in the design.
    ///
    private(set) internal var _snapshots: [ObjectID:StableObject]
    
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshot must not be mutable.
    ///
    init(design: Design, id: FrameID, snapshots: [StableObject]? = nil) {
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
    public var snapshots: [StableObject] {
        return Array(_snapshots.values)
    }
    
    /// Returns `true` if the frame contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _snapshots[id] != nil
    }

    public func contains(_ snapshot: StableObject) -> Bool {
        return _snapshots[snapshot.id] === snapshot
    }

    /// Return an object snapshots with given object ID.
    ///
    /// - Precondition: Frame must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> StableObject {
        guard let snapshot = _snapshots[id] else {
            preconditionFailure("Invalid object ID \(id) in frame \(self.id)")
        }
        return snapshot
    }
    
    /// Get an immutable graph view of the frame.
    ///
    public var graph: any ObjectGraph {
        return self
    }
}

