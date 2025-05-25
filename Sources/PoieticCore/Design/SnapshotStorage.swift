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
//typealias SnapshotStorage = RefCountedStorage<DesignObject>

// FIXME: [WIP] Remove this once happy (requires rewiring tests)
public class SnapshotStorage {
    public struct SnapshotReference {
        public let snapshot: ObjectSnapshot
        public let index: RefcountedObjectArray.Index
    }
    public struct RefCountCell {
        public let snapshot: ObjectSnapshot
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
    public var snapshots: some Collection<ObjectSnapshot> {
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
    public func snapshot(_ snapshotID: ObjectID) -> ObjectSnapshot? {
        guard let ref = _lookup[snapshotID] else {
            return nil
        }
        return ref.snapshot
    }
    
    @inlinable
    public subscript(_ snapshotID: ObjectID) -> ObjectSnapshot? {
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
    public func insertOrRetain(_ snapshot: ObjectSnapshot) {
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
        if _snapshots[ref.index].refCount <= 0 {
            _snapshots.remove(at: ref.index)
            _lookup[snapshotID] = nil
        }
    }
}

extension SnapshotStorage: Collection {
    public typealias Index = RefcountedObjectArray.Index
    public typealias Element = ObjectSnapshot
    
    public var startIndex: Index {
        return _snapshots.startIndex
    }
    
    public var endIndex: Index {
        return _snapshots.endIndex
    }
    
    public func index(after i: Index) -> Index {
        return _snapshots.index(after: i)
    }
    
    public subscript(position: Index) -> ObjectSnapshot {
        return _snapshots[position].snapshot
    }
}


/// A reference counted, ID-keyed storage for design entities.
///
/// Manages the lifecycle and ID-based lookup of design entities, with reference counting and weak
/// insertion-order preservation.
///
/// - Preserves insertion order (with gaps after deletions).
/// - Entities are removed only when ref-count reaches zero.
/// - Internal (backend) use only.
///
public class EntityTable<E> where E:Identifiable {
    public typealias Element = E
    public struct RefCountCell {
        public let element: Element
        public var refCount: Int
    }

    public typealias RefcountedObjectArray = GenerationalArray<RefCountCell>

    @usableFromInline
    var _items: RefcountedObjectArray
    @usableFromInline
    var _lookup: [E.ID:RefcountedObjectArray.Index]
    
    /// Create an empty snapshot storage.
    ///
    public init() {
        self._items = []
        self._lookup = [:]
    }
    
    /// Get a list of contained snapshots.
    ///
    public var items: some Collection<Element> {
        return _items.map { $0.element }
    }
    
    /// Returns `true` if the storage contains a snapshot with given ID.
    ///
    public func contains(_ id: Element.ID) -> Bool {
        _lookup[id] != nil
    }
    
    @inlinable
    public subscript(_ id: Element.ID) -> Element? {
        guard let index = _lookup[id] else {
            return nil
        }
        return _items[index].element
    }

    public func referenceCount(_ id: Element.ID) -> Int? {
        guard let index = _lookup[id] else {
            return nil
        }
        return _items[index].refCount
    }
    
    /// Inserts an item into the table, or retains existing item with the same ID.
    ///
    /// - Note: The method does not compare the content of the element, just the ID. To replace an item
    ///         in the table, the old one has to be removed first either by completely releasing it
    ///         or using ``remove(_:)``.
    ///
    public func insertOrRetain(_ item: Element) {
        if let index = _lookup[item.id] {
            let count = _items[index].refCount
            assert(count > 0)
            _items[index].refCount = count + 1
        }
        else {
            let index = _items.append(RefCountCell(element: item, refCount: 1))
            _lookup[item.id] = index
        }
    }

    public func retain(_ id: Element.ID) {
        guard let index = _lookup[id] else {
            preconditionFailure("Unknown ID \(id)")
        }
        
        let count = _items[index].refCount
        assert(count > 0)
        _items[index].refCount = count + 1
    }

    /// Insert a new item to the table and set its reference count to 1.
    ///
    /// - Precondition: given ID must exist in the table.
    ///
    public func insert(_ newItem: Element) {
        precondition(_lookup[newItem.id] == nil, "Duplicate item \(newItem.id). Did you mean insertOrRetain?")

        let index = _items.append(RefCountCell(element: newItem, refCount: 1))
        _lookup[newItem.id] = index
    }

    public func replace(_ newItem: Element) {
        guard let index = _lookup[newItem.id] else {
            preconditionFailure("Unknown ID \(newItem.id)")
        }
        _items[index] = RefCountCell(element: newItem, refCount: 1)
        _lookup[newItem.id] = index
    }

    /// Reduce reference count of an object. If the reference count reaches zero, the object is
    /// removed from the store.
    ///
    /// - Returns: `true` if the object was also removed, otherwise `false`.
    /// - Precondition: given ID must exist in the table.
    ///
    @discardableResult
    public func release(_ id: Element.ID) -> Bool {
        guard let index = _lookup[id] else {
            preconditionFailure("Unknown ID \(id)")
        }
        precondition(_items[index].refCount > 0, "Release failure: zero retains")
        
        _items[index].refCount -= 1
        if _items[index].refCount == 0 {
            _items.remove(at: index)
            _lookup[id] = nil
            return true
        }
        else {
            return false
        }
    }
    
    /// Remove object from the store, regardless of the reference count.
    ///
    /// It is rather recommended to use ``release(_:)``.
    ///
    /// - Precondition: given ID must exist in the table.
    ///
    public func remove(_ id: Element.ID) {
        guard let index = _lookup[id] else {
            preconditionFailure("Missing item \(id)")
        }
        
        _items.remove(at: index)
        _lookup[id] = nil
    }
}

extension EntityTable: Collection {
    public typealias Index = RefcountedObjectArray.Index
    
    public var startIndex: Index {
        return _items.startIndex
    }
    
    public var endIndex: Index {
        return _items.endIndex
    }
    
    public func index(after i: Index) -> Index {
        return _items.index(after: i)
    }
    
    public subscript(position: Index) -> Element {
        return _items[position].element
    }
}
