//
//  EntityTable.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/04/2025.
//

/// A reference counted, ID-keyed storage for design entities.
///
/// Manages the lifecycle and ID-based lookup of design entities, with reference counting and weak
/// insertion-order preservation.
///
/// - Preserves insertion order (with gaps after deletions).
/// - Entities are removed only when ref-count reaches zero.
/// - Internal (backend) use only.
///
public class RCTable<E> where E:Identifiable {
    public typealias Element = E
    public struct RCCell {
        public let element: Element
        public var refCount: Int
    }

    public typealias RCArray = GenerationalArray<RCCell>

    @usableFromInline
    var _items: RCArray
    @usableFromInline
    var _lookup: [E.ID:RCArray.Index]
    
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
            let index = _items.append(RCCell(element: item, refCount: 1))
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

        let index = _items.append(RCCell(element: newItem, refCount: 1))
        _lookup[newItem.id] = index
    }

    public func replace(_ newItem: Element) {
        guard let index = _lookup[newItem.id] else {
            preconditionFailure("Unknown ID \(newItem.id)")
        }
        _items[index] = RCCell(element: newItem, refCount: 1)
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

extension RCTable: Collection {
    public typealias Index = RCArray.Index
    
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
