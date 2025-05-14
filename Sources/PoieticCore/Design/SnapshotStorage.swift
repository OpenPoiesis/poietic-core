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
    public struct SnapshotReference {
        public let snapshot: DesignObject
        public let index: RefcountedObjectArray.Index
    }
    public struct RefCountCell {
        public let snapshot: DesignObject
        public var refCount: Int
    }

    public typealias RefcountedObjectArray = GenerationalArray<RefCountCell>

    var _snapshots: RefcountedObjectArray
    @usableFromInline
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
        return _snapshots.map { $0.snapshot }
    }
    
    /// Returns `true` if the storage contains a snapshot with given ID.
    ///
    public func contains(_ snapshotID: ObjectID) -> Bool {
        _lookup[snapshotID] != nil
    }
    
    /// Get a snapshot by snapshot ID, if it exists.
    ///
    @inlinable
    public func snapshot(_ snapshotID: ObjectID) -> DesignObject? {
        guard let ref = _lookup[snapshotID] else {
            return nil
        }
        return ref.snapshot
    }
    
    @inlinable
    public subscript(_ snapshotID: ObjectID) -> DesignObject? {
        return snapshot(snapshotID)
    }

    public func referenceCount(_ snapshotID: ObjectID) -> Int? {
        guard let ref = _lookup[snapshotID] else {
            return nil
        }
        return _snapshots[ref.index].refCount
    }
    
    /// Inserts a snapshot into the store, if it does not already exist or increases reference
    /// count of a snapshot.
    ///
    /// - Precondition: If the store already contains snapshot with given ID it must be the same
    ///   snapshot.
    public func insertOrRetain(_ snapshot: DesignObject) {
        if let ref = _lookup[snapshot.snapshotID] {
            let count = _snapshots[ref.index].refCount
            precondition(count > 0)
            // HINT: When this happens, it is very likely that uniqueness of IDs was not verified.
            // HINT: Places to look at: persistent store or frame loader.
            precondition(_snapshots[ref.index].snapshot === snapshot)
            _snapshots[ref.index].refCount = count + 1
        }
        else {
            let index = _snapshots.append(RefCountCell(snapshot: snapshot, refCount: 1))
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
        precondition(_snapshots[ref.index].refCount > 0, "Release failure: zero retains")
        
        _snapshots[ref.index].refCount -= 1
        if _snapshots[ref.index].refCount == 0 {
            _snapshots.remove(at: ref.index)
            _lookup[snapshotID] = nil
        }
    }
}

extension SnapshotStorage: Collection {
    public typealias Index = RefcountedObjectArray.Index
    public typealias Element = DesignObject
    
    public var startIndex: Index {
        return _snapshots.startIndex
    }
    
    public var endIndex: Index {
        return _snapshots.endIndex
    }
    
    public func index(after i: Index) -> Index {
        return _snapshots.index(after: i)
    }
    
    public subscript(position: Index) -> DesignObject {
        return _snapshots[position].snapshot
    }
}
