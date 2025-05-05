//
//  SnapshotStorage.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/04/2025.
//

/// Reference counted storage of object snapshots.
///
/// Features of the snapshot storage:
/// - Reference counting with ``insertOrRetain(_:)`` and ``release(_:)``.
/// - Fast lookup by snapshot ID ``snapshot(_:)`` and ``contains(_:)``.
///
/// Generally the snapshot storage tries to preserve relative order of objects after insertion.
/// Exception is insertion after object removal, when an object might be inserted in between
/// existing objects, disrupting local order of the neighbours. Note that the general order of
/// insertion is not preserved.
///
public class SnapshotStorage {
    // TODO: [WIP] Add subscript by ID.
    struct SnapshotReference {
        let snapshot: DesignObject
        let index: RefcountedObjectArray.Index
    }

    typealias RefcountedObjectArray = GenerationalArray<DesignObject>

    var _snapshots: RefcountedObjectArray
    var _lookup: [ObjectID:SnapshotReference]
    
    /// Create an empty snapshot storage.
    ///
    public init() {
        self._snapshots = []
        self._lookup = [:]
    }
    
    /// Get a list of contained snapshots.
    ///
    public var snapshots: some Collection<DesignObject> {
        return _snapshots
    }
    
    /// Returns `true` if the storage contains a snapshot with given ID.
    ///
    public func contains(_ snapshotID: ObjectID) -> Bool {
        _lookup[snapshotID] != nil
    }
    
    /// Get a snapshot by snapshot ID, if it exists.
    ///
    public func snapshot(_ snapshotID: ObjectID) -> DesignObject? {
        guard let ref = _lookup[snapshotID] else {
            return nil
        }
        return ref.snapshot
    }
    
    /// Inserts a snapshot into the store, if it does not already exist or increases reference
    /// count of a snapshot.
    ///
    /// - Precondition: If the store already contains snapshot with given ID it must be the same
    ///   snapshot.
    public func insertOrRetain(_ snapshot: DesignObject) {
        // TODO: [WIP] Make this two separate methods insert(DesignObject)/retain(ObjectID)
        // TODO: [WIP] Remove refcount from the design object, move it here.
        
        if let ref = _lookup[snapshot.snapshotID] {
            let count = _snapshots[ref.index]._refCount
            precondition(count > 0)
            // HINT: When this happens, it is very likely that uniqueness of IDs was not verified.
            // HINT: Places to look at: persistent store or frame loader.
            precondition(_snapshots[ref.index] === snapshot)
            _snapshots[ref.index]._refCount = count + 1
        }
        else {
            precondition(snapshot._refCount == 0)
            snapshot._refCount = 1
            let index = _snapshots.append(snapshot)
            _lookup[snapshot.snapshotID] = SnapshotReference(snapshot: snapshot, index: index)
        }
    }
    
    /// Reduce reference count of an object. If the reference count reaches zero, the object is
    /// removed from the store.
    ///
    public func release(_ snapshotID: ObjectID) {
        guard let ref = _lookup[snapshotID] else {
            preconditionFailure("Missing snapshot \(snapshotID)")
        }
        precondition(_snapshots[ref.index]._refCount > 0, "Release failure: zero retains")
        
        _snapshots[ref.index]._refCount -= 1
        if _snapshots[ref.index]._refCount == 0 {
            _snapshots.remove(at: ref.index)
            _lookup[snapshotID] = nil
        }
    }
}
