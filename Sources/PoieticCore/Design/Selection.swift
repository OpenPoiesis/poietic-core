//
//  Selection.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 18/01/2025.
//

import Collections

/// Component denoting a selection change.
///
/// Example use-cases of this component:
///
/// - Selection tool in an application on a mouse interaction.
/// - Search feature in an application
///
/// - SeeAlso: ``Selection/apply(_:)``
///
public enum SelectionChange: Component {
    case appendOne(ObjectID)
    case append([ObjectID])
    case replaceAllWithOne(ObjectID)
    case replaceAll([ObjectID])
    case removeAll
    case toggle(ObjectID)
}

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
    public private(set) var ids: OrderedSet<ObjectID> = []
    
    public var startIndex: Index { ids.startIndex }
    public var endIndex: Index { ids.endIndex }
    public func index(after i: Index) -> Index { ids.index(after: i) }
    public subscript(i: Index) -> ObjectID { return ids[i] }
   
    /// Create an empty selection.
    public init() {
        self.ids = []
    }
    
    /// Create a selection of given IDs
    ///
    public init(_ ids:[ObjectID]) {
        self.ids = OrderedSet(ids)
    }
    public init(_ ids:OrderedSet<ObjectID>) {
        self.ids = ids
    }
    

    /// Returns `true` if the selection contains a given ID.
    public func contains(_ id: ObjectID) -> Bool {
        return ids.contains(id)
    }
    
    public var isEmpty: Bool {
        return ids.isEmpty
    }
    
    /// Returns an object ID if it is the only object in the selection, otherwise `nil`.
    public func selectionOfOne() -> ObjectID? {
        if ids.count == 1 {
            return ids.first!
        }
        else {
            return nil
        }
    }
    
    /// Apply a selection change.
    ///
    /// Use this function in a selection system that is typically triggered by an user interaction
    /// such as tool use.
    ///
    public func apply(_ change: SelectionChange) {
        switch change {
        case .appendOne(let id): self.append([id])
        case .append(let ids): self.append(ids)
        case .replaceAllWithOne(let id): self.replaceAll([id])
        case .replaceAll(let ids): self.replaceAll(ids)
        case .removeAll: self.removeAll()
        case .toggle(let id): self.toggle(id)
        }
    }
    
    /// Append the ID if it is not already present in the selection.
    public func append(_ id: ObjectID) {
        ids.append(id)
    }
    
    /// Append IDs to the selection, if they are not already present in the selection.
    ///
    public func append(_ ids: [ObjectID]) {
        self.ids.append(contentsOf: ids)
    }

    /// Replace all objects in the selection.
    ///
    public func replaceAll(_ ids: [ObjectID]) {
        self.ids.removeAll()
        self.ids.append(contentsOf: ids)
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
        if ids.contains(id) {
            ids.remove(id)
        }
        else {
            ids.append(id)
        }
    }
}

extension Selection /* : SetAlgebra */ {
    public func union(_ other: __owned Selection) -> Self {
        return Self(self.ids.union(other.ids))
    }
    
    public func intersection(_ other: Selection) -> Self {
        return Self(self.ids.intersection(other.ids))
    }
    
    public func symmetricDifference(_ other: __owned Selection) -> Self {
        return Self(self.ids.symmetricDifference(other.ids))
    }
    
    public func formUnion(_ other: __owned Selection) {
        self.ids.formUnion(other.ids)
    }
    
    public func formIntersection(_ other: Selection) {
        self.ids.formIntersection(other.ids)
    }
    
    public func formSymmetricDifference(_ other: __owned Selection) {
        self.ids.formSymmetricDifference(other.ids)
    }
    
    public static func == (lhs: Selection, rhs: Selection) -> Bool {
        lhs.ids == rhs.ids
    }
}
