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
public protocol Frame: Graph {
    /// Design to which the frame belongs.
    var design: Design { get }
    
    var id: FrameID { get }
    
    // TODO: Change this to Sequence<ObjectSnapshot>
    /// Get a list of all snapshots in the frame.
    ///
    var snapshots: [ObjectSnapshot] { get }

    /// Check whether the frame contains an object with given ID.
    ///
    /// - Returns: `true` if the frame contains the object, otherwise `false`.
    ///
    func contains(_ id: ObjectID) -> Bool

    /// Return an object with given ID from the frame or `nil` if the frame
    /// does not contain such object.
    ///
    func object(_ id: ObjectID) -> ObjectSnapshot
    
    /// Get an object by an ID.
    ///
    subscript(id: ObjectID) -> ObjectSnapshot { get }

    
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
    public subscript(id: ObjectID) -> ObjectSnapshot {
        get {
            self.object(id)
        }
    }

    /// Get a list of object IDs that are referenced within the frame
    /// but do not exist in the frame.
    ///
    /// Frame with broken references can not be made stable and accepted
    /// by the design.
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
    /// by the design.
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
    
    /// Get first object of given type.
    ///
    /// This method is used to find singleton objects, for example
    /// design info object.
    ///
    public func first(type: ObjectType) -> ObjectSnapshot? {
        return snapshots.first { $0.type === type }
    }

    /// Filter snapshots by object type.
    ///
    /// - Note: The type is compared for identity, that means that the snapshots
    /// must have exactly the provided object type instance associated.
    ///
    public func filter(type: ObjectType) -> [ObjectSnapshot] {
        return snapshots.filter { $0.type === type }
    }
    
    /// Filter objects with given trait.
    ///
    /// Returns objects that have the specified trait.
    ///
    /// - Note: The trait is compared using identity, therefore the snapshot
    ///   matching the filter must have exactly the provided trait associated
    ///   with the object's type.
    ///
    public func filter(trait: Trait) -> [ObjectSnapshot] {
        return snapshots.filter {
            $0.type.traits.contains { $0 === trait }
        }
    }

    /// Filter objects by a closure.
    /// 
    public func filter(_ test: (ObjectSnapshot) -> Bool) -> [ObjectSnapshot] {
        return snapshots.filter(test)
    }

    /// Get the first object satisfying the condition.
    ///
    /// If multiple objects satisfy the condition, then which one is
    /// returned is undefined.
    ///
    public func first(where predicate: (ObjectSnapshot) -> Bool) -> ObjectSnapshot? {
        return snapshots.first(where: predicate)
    }

    /// Get the first object with given trait.
    ///
    /// If multiple objects have the trait, then which one is
    /// returned is undefined.
    ///
    /// Use this only for traits of singletons.
    ///
    public func first(trait: Trait) -> ObjectSnapshot? {
        return snapshots.first { $0.type.hasTrait(trait) }
    }

    // TODO: Use Node as argument
    public func filterNodes(_ block: (ObjectSnapshot) -> Bool) -> [Node] {
        return snapshots.compactMap {
            if let node = Node($0), block($0) {
                return node
            }
            else {
                return nil
            }
        }
    }

    public func filterEdges(_ block: (Edge) -> Bool) -> [Edge] {
        return snapshots.compactMap {
            if let edge = Edge($0), block(edge) {
                return edge
            }
            else {
                return nil
            }
        }
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

/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
///
extension Frame /* Graph */ {
    public var frame: Frame { self }

    /// Get a node by ID.
    ///
    /// - Precondition: The object must exist and must be a node.
    ///
    public func node(_ id: ObjectID) -> Node {
        if let node = Node(frame[id]) {
            return node
        }
        else {
            preconditionFailure("Frame object \(id) must be a node.")
        }
    }

    /// Get an edge by ID.
    ///
    /// - Precondition: The object must exist and must be an edge.
    ///
    public func edge(_ id: ObjectID) -> Edge {
        if let edge = Edge(frame[id]) {
            return edge
        }
        else {
            preconditionFailure("Frame object \(id) must be an edge.")
        }
    }

    public func contains(node nodeID: ObjectID) -> Bool {
        if contains(nodeID) {
            let obj = self[nodeID]
            return obj.structure.type == .node
        }
        else {
            return false
        }
    }

    public func contains(edge edgeID: ObjectID) -> Bool {
        if contains(edgeID) {
            let obj = self[edgeID]
            return obj.structure.type == .edge
        }
        else {
            return false
        }
    }

    public func neighbours(_ node: ObjectID, selector: NeighborhoodSelector) -> [Edge] {
        fatalError("Neighbours of mutable graph not implemented")
    }
    
    public var nodes: [Node] {
        return self.frame.snapshots.compactMap {
            Node($0)
        }
    }
    
    public var edges: [Edge] {
        return self.frame.snapshots.compactMap {
            Edge($0)
        }
    }
}


/// Stable design frame that can not be mutated.
///
/// The stable frame is a collection of object versions that together represent
/// a version snapshot of a design. The frame is immutable.
///
/// To create a derivative frame from a stable frame use
/// ``Design/deriveFrame(original:id:)``.
///
/// - SeeAlso: ``MutableFrame``
///
public class StableFrame: Frame {
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
    private(set) internal var _snapshots: [ObjectID:ObjectSnapshot]
    
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshot must not be mutable.
    ///
    init(design: Design, id: FrameID, snapshots: [ObjectSnapshot]? = nil) {
        precondition(snapshots?.allSatisfy({ !$0.state.isMutable }) ?? true,
                     "Trying to create a stable frame with one or more mutable snapshots")
        
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
        return self
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
        return snapshots.first { $0.name == name }
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
            return self[id]
        }
        else if let snapshot = object(named: stringReference) {
            return snapshot
        }
        else {
            return nil
        }
    }
}
