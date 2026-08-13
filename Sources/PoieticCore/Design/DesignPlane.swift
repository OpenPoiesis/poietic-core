//
//  DesignPlane.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//

/// Design plane that has been accepted and can not be changed.
///
/// The stable plane is a collection of object versions that together represent
/// a version snapshot of a design. The plane is immutable.
///
/// Stable planes can not be created directly. They can be created only from
/// mutable planes through validation using ``Design/accept(_:appendHistory:)``.
///
/// To create a derivative plane from a stable plane use
/// ``Design/createPlane(deriving:id:)``.
///
/// - SeeAlso: ``TransientPlane``
///
public final class DesignPlane: Plane, RCTableElement {
    /// Design to which the plane belongs.
    public unowned let design: Design
    
    /// ID of the plane.
    ///
    /// ID is unique within the design.
    ///
    public let id: PlaneID
    public var storageKey: PlaneID { id }

    /// Version snapshots contained in the plane.
    ///
    /// Snapshots might be shared between planes.
    ///
    internal let _snapshots: [ObjectSnapshot]
    @usableFromInline
    internal let _lookup: [ObjectID:ObjectSnapshot]
    @usableFromInline
    internal let _graph: Graph<ObjectID, DesignObjectEdge>
   
    public var isEmpty: Bool { _snapshots.isEmpty }
    
    /// Create a new stable plane with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshots must have referential integrity.
    ///
    init(design: Design, id: PlaneID, snapshots: [ObjectSnapshot] = []) {
        // TODO: [IMPORTANT] Rename to init(design:id:unsafeSnapshots:)
        self.design = design
        self.id = id
        self._snapshots = snapshots
        let lookup = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.objectID, $0 ) })
        let nodeKeys = snapshots.compactMap {
            if $0.topology == .node { $0.objectID }
            else { nil }
        }
        let edges: [DesignObjectEdge] = snapshots.compactMap {
            guard case let .edge(originID, targetID) = $0.topology else {
                return nil
            }
            guard let origin = lookup[originID], let target = lookup[targetID] else {
                return nil
            }
            return DesignObjectEdge($0, origin: origin, target: target)
        }
        self._graph = Graph(nodes: nodeKeys, edges: edges)
        self._lookup = lookup
        // TODO: [IMPORTANT] Enable this
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
    
    /// Returns `true` if the plane contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _lookup[id] != nil
    }
    
    /// Filters the IDs and returns only those that are contained in the plane.
    public func contained(_ ids: some Collection<ObjectID>) -> [ObjectID] {
        ids.filter { _lookup[$0] != nil }
    }
    
    /// Return an object snapshots with given object ID.
    ///
    /// - Precondition: Plane must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> ObjectSnapshot? {
        return _lookup[id]
    }
}

