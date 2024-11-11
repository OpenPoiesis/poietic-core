//
//  Frame.swift
//
//
//  Created by Stefan Urbanek on 13/02/2023.
//

/// Protocol for version frames.
///
/// Fame Base is a protocol for all version frame types: ``TransientFrame`` and
/// ``StableFrame``
///
public protocol Frame: Graph {
    associatedtype Snapshot: ObjectSnapshot
    /// Design to which the frame belongs.
    var design: Design { get }
    
    var id: FrameID { get }
    
    /// Get a list of all snapshots in the frame.
    ///
    var snapshots: [Snapshot] { get }

    /// Check whether the frame contains an object with given ID.
    ///
    /// - Returns: `true` if the frame contains the object, otherwise `false`.
    ///
    func contains(_ id: ObjectID) -> Bool
    func contains(_ snapshot: Snapshot) -> Bool

    /// Return an object with given ID from the frame or `nil` if the frame
    /// does not contain such object.
    ///
    func object(_ id: ObjectID) -> Snapshot
    
    /// Get an object by an ID.
    ///
    subscript(id: ObjectID) -> Snapshot { get }

    
    /// Asserts that the frame satisfies the given constraint. Raises a
    /// `ConstraintViolation` error if the frame objects violate the constraints.
    ///
    /// - Throws: `ConstraintViolation` when the frame violates given constraint.
    ///
    func assert(constraint: Constraint) throws
    func brokenReferences() -> [ObjectID]

    func hasReferentialIntegrity() -> Bool
    
    func filter(type: ObjectType) -> [Snapshot]
}

extension Frame {
    public subscript(id: ObjectID) -> Snapshot {
        get {
            self.object(id)
        }
    }
    /// Get a list of missing IDs from the list of IDs
    public func missing(_ ids: [ObjectID]) -> [ObjectID] {
        return ids.filter { !contains($0) }
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
    public func brokenReferences(snapshot: Snapshot) -> [ObjectID] {
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
    public func first(type: ObjectType) -> Snapshot? {
        return snapshots.first { $0.type === type }
    }

    /// Filter snapshots by object type.
    ///
    /// - Note: The type is compared for identity, that means that the snapshots
    /// must have exactly the provided object type instance associated.
    ///
    public func filter(type: ObjectType) -> [Snapshot] {
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
    public func filter(trait: Trait) -> [Snapshot] {
        return snapshots.filter {
            $0.type.traits.contains { $0 === trait }
        }
    }

    /// Filter objects by a closure.
    /// 
    public func filter(_ test: (Snapshot) -> Bool) -> [Snapshot] {
        return snapshots.filter(test)
    }

    /// Get the first object satisfying the condition.
    ///
    /// If multiple objects satisfy the condition, then which one is
    /// returned is undefined.
    ///
    public func first(where predicate: (Snapshot) -> Bool) -> Snapshot? {
        return snapshots.first(where: predicate)
    }

    /// Get the first object with given trait.
    ///
    /// If multiple objects have the trait, then which one is
    /// returned is undefined.
    ///
    /// Use this only for traits of singletons.
    ///
    public func first(trait: Trait) -> Snapshot? {
        return snapshots.first { $0.type.hasTrait(trait) }
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

    public func filter(_ predicate: Predicate) -> [Snapshot] {
        return snapshots.filter {
            predicate.match(frame: self, object: $0)
        }
    }
}

/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
///
extension Frame /* Graph */ {
    /// Get a node by ID.
    ///
    /// - Precondition: The object must exist and must be a node.
    ///
    public func node(_ id: ObjectID) -> Node {
        if let node = Node(self[id]) {
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
        if let edge = Edge(self[id]) {
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
        return self.snapshots.compactMap {
            Node($0)
        }
    }
    
    public var edges: [Edge] {
        return self.snapshots.compactMap {
            Edge($0)
        }
    }
    
    /// Get list of objects that have no parent.
    public func top() -> [Snapshot] {
        self.filter { $0.parent == nil }
    }
    
    public func selectNodes(_ predicate: Predicate) -> [Node] {
        return nodes.filter { predicate.match(frame: self, object: $0.snapshot) }
    }
    public func selectEdges(_ predicate: Predicate) -> [Edge] {
        return edges.filter { predicate.match(frame: self, object: $0.snapshot) }
    }
    
    public func hood(_ nodeID: ObjectID, selector: NeighborhoodSelector) -> Neighborhood {
        let edges: [Edge]
        switch selector.direction {
        case .incoming: edges = incoming(nodeID)
        case .outgoing: edges = outgoing(nodeID)
        }
        let filtered: [Edge] = edges.filter {
            selector.predicate.match(frame: self, object: $0.snapshot)
        }
        
        return Neighborhood(graph: self,
                            nodeID: nodeID,
                            direction: selector.direction,
                            edges: filtered)
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
    public func object(named name: String) -> Snapshot? {
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
    public func object(stringReference: String) -> Snapshot? {
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
