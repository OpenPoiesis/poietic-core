//
//  Selection.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 18/01/2025.
//

/// Collection of selected objects.
///
/// An ordered set of object identifiers with convenience methods to support typical user
/// application actions. For example toggling a selected object using `Shift` key can be done
/// with the ``toggle(_:)`` method.
///
/// Design frame has several methods related to application use of selection for inspection
/// of selected objects, such as ``Frame/distinctAttribute(_:ids:)``, ``Frame/distinctTypes(_:)``,
/// ``Frame/sharedTraits(_:)``.
///
/// When a selection is preserved between changes, it is recommended to sanitise the objects
/// in the selection using the ``Frame/existing(from:)`` function.
///
public final class Selection: Collection, Component {
    public typealias Index = [ObjectID].Index
    
    /// List of object IDs contained in the selection.
    /// 
    /// When a selection is preserved between changes, it is recommended to sanitise the objects
    /// in the selection using the ``Frame/existing(from:)`` function.
    ///
    public private(set) var ids: [ObjectID] = []
    
    public var startIndex: Index { ids.startIndex }
    public var endIndex: Index { ids.endIndex }
    public func index(after i: Index) -> Index { ids.index(after: i) }
    public subscript(i: Index) -> ObjectID { return ids[i] }
    
    public init() {
        self.ids = []
    }
    
    /// Create a selection of given IDs
    ///
    public init(_ ids:[ObjectID]) {
        self.ids = ids
    }
    
    
    public func contains(_ id: ObjectID) -> Bool {
        guard !ids.isEmpty else { return false }
        return ids.contains(id)
    }
    
    public var isEmpty: Bool {
        return ids.isEmpty
    }
    
    /// Append the ID if it is not already present in the selection.
    public func append(_ id: ObjectID) {
        guard !contains(id) else {
            return
        }
        ids.append(id)
    }
    
    /// Append IDs to the selection, if they are not already present in the selection.
    ///
    public func append(_ ids: [ObjectID]) {
        for id in ids {
            guard !contains(id) else {
                return
            }
            self.ids.append(id)
        }
    }

    /// Replace all objects in the selection.
    ///
    public func replaceAll(_ ids: [ObjectID]) {
        self.ids.removeAll()
        self.ids += ids
    }

    
    /// Remove all objects in the selection.
    ///
    public func removeAll() {
        ids.removeAll()
    }
    
    /// Add the ID to the selection if it is not already present, otherwise remove it from the
    /// selection.
    ///
    public func toggle(_ id: ObjectID) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        }
        else {
            ids.append(id)
        }
    }
}

extension Selection: SetAlgebra {
    public func union(_ other: __owned Selection) -> Self {
        var result: [ObjectID] = []
        for item in other {
            if !result.contains(item) {
                result.append(item)
            }
        }
        return Self(result)
    }
    
    public func intersection(_ other: Selection) -> Self {
        var result: [ObjectID] = []
        for item in other {
            if ids.contains(item) {
                result.append(item)
            }
        }
        return Self(result)
    }
    
    public func symmetricDifference(_ other: __owned Selection) -> Self {
        fatalError("NOT IMPLEMENTED")
    }
    
    public func insert(_ newMember: __owned ObjectID) -> (inserted: Bool, memberAfterInsert: ObjectID) {
        if !ids.contains(newMember) {
            ids.append(newMember)
            return (true, newMember)
        }
        else {
            return (false, newMember)
        }
    }
    
    public func remove(_ member: ObjectID) -> ObjectID? {
        if let index = ids.firstIndex(of: member) {
            let obj = ids[index]
            ids.remove(at: index)
            return obj
        }
        else {
            return nil
        }
    }
    
    public func update(with newMember: __owned ObjectID) -> ObjectID? {
        // do nothing
        return newMember
    }
    
    public func formUnion(_ other: __owned Selection) {
        fatalError("NOT IMPLEMENTED")
    }
    
    public func formIntersection(_ other: Selection) {
        fatalError("NOT IMPLEMENTED")
    }
    
    public func formSymmetricDifference(_ other: __owned Selection) {
        fatalError("NOT IMPLEMENTED")
    }
    
    public static func == (lhs: Selection, rhs: Selection) -> Bool {
        lhs.ids == rhs.ids
    }
}
