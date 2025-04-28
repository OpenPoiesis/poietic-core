//
//  SnapshotStorage.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/04/2025.
//

class SnapshotStorage {
    
    struct SnapshotReference {
        let snapshot: DesignObject
        let index: RefcountedObjectArray.Index
    }
    typealias RefcountedObjectArray = GenerationalArray<DesignObject>

    var _snapshots: RefcountedObjectArray
    var _lookup: [ObjectID:SnapshotReference]
    
    public init() {
        self._snapshots = []
        self._lookup = [:]
    }
    
    var snapshots: some Collection<DesignObject> {
        return _snapshots
    }
    
    func contains(_ snapshotID: ObjectID) -> Bool {
        _lookup[snapshotID] != nil
    }
    
    // TODO: Used only in tests
    func snapshot(_ snapshotID: ObjectID) -> DesignObject? {
        guard let ref = _lookup[snapshotID] else {
            return nil
        }
        return ref.snapshot
    }
    
    func insertOrRetain(_ snapshot: DesignObject) {
        if let ref = _lookup[snapshot.snapshotID] {
            let count = _snapshots[ref.index]._refCount
            assert(count > 0)
            // HINT: When this happens, it is very likely that uniqueness of IDs was not verified.
            // HINT: Places to look at: persistent store or frame loader.
            assert(_snapshots[ref.index] === snapshot)
            _snapshots[ref.index]._refCount = count + 1
        }
        else {
            assert(snapshot._refCount == 0)
            snapshot._refCount = 1
            let index = _snapshots.append(snapshot)
            _lookup[snapshot.snapshotID] = SnapshotReference(snapshot: snapshot, index: index)
        }
    }
    
    func release(_ snapshotID: ObjectID) {
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
