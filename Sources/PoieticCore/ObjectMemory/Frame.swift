//
//  Frame.swift
//
//
//  Created by Stefan Urbanek on 13/02/2023.
//

/// Protocol for version frames.
///
/// Fame Base is a protocol for all version frame types: ``MutableFrame`` and
/// ``StableFrame``
///
public protocol Frame {
    /// Memory to which the frame belongs.
    var memory: ObjectMemory { get }
    
    var id: FrameID { get }
    
    // TODO: Change this to Sequence<ObjectSnapshot>
    /// Get a list of all snapshots in the frame.
    ///
    var snapshots: [ObjectSnapshot] { get }

    /// Get view of the frame as a graph.
    ///
    var graph: Graph { get }

    /// Check whether the frame contains an object with given ID.
    ///
    /// - Returns: `true` if the frame contains the object, otherwise `false`.
    ///
    func contains(_ id: ObjectID) -> Bool

    /// Return an object with given ID from the frame or `nil` if the frame
    /// does not contain such object.
    ///
    func object(_ id: ObjectID) -> ObjectSnapshot
    
    /// Asserts that the frame satisfies the given constraint. Raises a
    /// `ConstraintViolation` error if the frame objects violate the constraints.
    ///
    /// - Throws: `ConstraintViolation` when the frame violates given constraint.
    ///
    func assert(constraint: Constraint) throws
    func brokenReferences() -> [ObjectID]

    func hasReferentialIntegrity() -> Bool
    
    func filter(type: ObjectType) -> [ObjectSnapshot]
}

extension Frame {
    /// Get a list of object IDs that are referenced within the frame
    /// but do not exist in the frame.
    ///
    /// Frame with broken references can not be made stable and accepted
    /// by the memory.
    ///
    /// The following references from the snapshot are being considered:
    ///
    /// - If the structure type is an edge (``StructuralComponent/edge(_:_:)``)
    ///   then the origin and target is considered.
    /// - All children – ``ObjectSnapshot/children``.
    /// - The object's parent – ``ObjectSnapshot/parent``.
    ///
    /// - Note: This is semi-internal function to validate correct workings
    ///   of the system. You should rarely use it. Typical scenario when you
    ///   want to use this function is when you are constructing a frame
    ///   in an unsafe way.
    ///
    /// - SeeAlso: ``Frame/hasReferentialIntegrity()``
    ///
    public func brokenReferences() -> [ObjectID] {
        // NOTE: Sync with brokenReferences(snapshot:)
        //
        var broken: Set<ObjectID> = []
        
        for snapshot in snapshots {
            if case let .edge(origin, target) = snapshot.structure {
                if !contains(origin) {
                    broken.insert(origin)
                }
                if !contains(target) {
                    broken.insert(target)
                }
            }
            broken.formUnion(snapshot.children.filter { !contains($0) })
            if let parent = snapshot.parent, !contains(parent) {
                broken.insert(parent)
            }
        }

        return Array(broken)
    }

    /// Return a list of objects that the provided object refers to and
    /// that do not exist within the frame.
    ///
    /// Frame with broken references can not be made stable and accepted
    /// by the memory.
    ///
    /// The following references from the snapshot are being considered:
    ///
    /// - If the structure type is an edge (``StructuralComponent/edge(_:_:)``)
    ///   then the origin and target is considered.
    /// - All children – ``ObjectSnapshot/children``.
    /// - The object's parent – ``ObjectSnapshot/parent``.
    ///
    /// - SeeAlso: ``Frame/brokenReferences()``,
    ///     ``Frame/hasReferentialIntegrity()``
    ///
    public func brokenReferences(snapshot: ObjectSnapshot) -> [ObjectID] {
        // NOTE: Sync with brokenReferences() for all snapshots within the frame
        //
        var broken: Set<ObjectID> = []
        
        if case let .edge(origin, target) = snapshot.structure {
            if !contains(origin) {
                broken.insert(origin)
            }
            if !contains(target) {
                broken.insert(target)
            }
        }
        broken.formUnion(snapshot.children.filter { !contains($0) })
        if let parent = snapshot.parent, !contains(parent) {
            broken.insert(parent)
        }

        return Array(broken)
    }

    
    /// Function that determines whether the frame has a referential integrity.
    ///
    /// - SeeAlso: ``Frame/brokenReferences()``
    ///

    public func hasReferentialIntegrity() -> Bool {
        return brokenReferences().isEmpty
    }
    
    public func assert(constraint: Constraint) throws {
        let violators = constraint.check(self)
        if violators.isEmpty {
            return
        }
        let violation = ConstraintViolation(constraint: constraint,
                                            objects:violators)
        throw violation
    }
    
    public func filter(type: ObjectType) -> [ObjectSnapshot] {
        return snapshots.filter { $0.type === type }
    }
    
    public func filter<T>(component type: T.Type) -> [(ObjectSnapshot, T)]
            where T : Component {
        return snapshots.compactMap {
            if let component: T = $0.components[type]{
                ($0, component)
            }
            else {
                nil
            }
        }
    }
    
    public func filter(_ predicate: Predicate) -> [ObjectSnapshot] {
        return snapshots.filter {
            predicate.match(frame: self, object: $0)
        }
    }
}

/// Stable design frame that can not be mutated.
///
/// The stable frame is a collection of object versions that together represent
/// a version snapshot of a design. The frame is immutable.
///
/// To create a derivative frame from a stable frame use
/// ``ObjectMemory/deriveFrame(original:id:)``.
///
/// - SeeAlso: ``MutableFrame``
///
public class StableFrame: Frame {
    /// Memory to which the frame belongs.
    public let memory: ObjectMemory
    
    /// ID of the frame.
    ///
    /// ID is unique within the object memory.
    ///
    public let id: FrameID
    
    /// Versions of objects in the plane.
    ///
    /// Objects not in the map do not exist in the version plane, but might
    /// exist in the object memory.
    ///
    private(set) internal var _snapshots: [ObjectID:ObjectSnapshot]
    
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshot must not be mutable.
    ///
    init(memory: ObjectMemory, id: FrameID, snapshots: [ObjectSnapshot]? = nil) {
        precondition(snapshots?.allSatisfy({ !$0.state.isMutable }) ?? true,
                     "Trying to create a stable frame with one or more mutable snapshots")
        
        self.memory = memory
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
    public var snapshots: [ObjectSnapshot] {
        return Array(_snapshots.values)
    }
    
    /// Returns `true` if the frame contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _snapshots[id] != nil
    }
    
    /// Return an object snapshots with given object ID.
    ///
    public func object(_ id: ObjectID) -> ObjectSnapshot {
        guard let snapshot = _snapshots[id] else {
            fatalError("Frame \(self.id) does not contain object \(id)")
        }
        return snapshot
    }
    
    /// Get an immutable graph view of the frame.
    ///
    public var graph: Graph {
        return UnboundGraph(frame: self)
    }
}

extension Frame {
    /// Get object by a name, if the object contains a named component.
    ///
    /// A method that searches the frame for a first object with
    /// a name component and with the given name.
    ///
    /// If the frame contains multiple objects with the same name,
    /// then one is returned arbitrarily. Subsequent calls of the method
    /// with the same name does not guarantee that the same object will
    /// be returned.
    ///
    /// - Returns: First object found with given name or `nil` if no object
    ///   with the given name exists.
    ///
    ///
    public func object(named name: String) -> ObjectSnapshot? {
        for object in snapshots {
            guard let component: NameComponent = object[NameComponent.self] else {
                continue
            }
            if component.name == name {
                return object
            }
        }
        return nil
    }
    
    /// Get an object by a string reference - the string might be an object name
    /// or object ID.
    ///
    /// First the string is converted to object ID and an object with the given
    /// ID is searched for. If not found, then all named objects are searched
    /// and the first one with given name is returned. If multiple objects
    /// have the same name, then one is returned arbitrarily. Subsequent
    /// calls to the method with the same name do not guarantee that
    /// the same object will be returned if multiple objects have the same name.
    ///
    public func object(stringReference: String) -> ObjectSnapshot? {
        if let id = ObjectID(stringReference), contains(id) {
            return object(id)
        }
        else if let snapshot = object(named: stringReference) {
            return snapshot
        }
        else {
            return nil
        }
    }
}
