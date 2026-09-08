//
//  Plane.swift
//
//
//  Created by Stefan Urbanek on 13/02/2023.
//

/// Protocol for version planes.
///
/// Fame Base is a protocol for all version plane types: ``TransientPlane`` and
/// ``DesignPlane``
///
public protocol Plane:
    GraphProtocol where NodeKey == ObjectID,
                        EdgeKey == ObjectID,
                        Edge == DesignObjectEdge {
    /// Design to which the plane belongs.
    var design: Design { get }
    
    var id: PlaneID { get }
    
    /// Get a list of all snapshots in the plane.
    ///
    var snapshots: [ObjectSnapshot] { get }
    
    /// Get a list of object IDs in the plane.
    var objectIDs: [ObjectID] { get }

    /// Check whether the plane contains an object with given ID.
    ///
    /// - Returns: `true` if the plane contains the object, otherwise `false`.
    ///
    func contains(_ objectID: ObjectID) -> Bool
    
    /// Return an object with given ID from the plane or `nil` if the plane
    /// does not contain such object.
    ///
    func object(_ objectID: ObjectID) -> ObjectSnapshot?
    
    /// Get an object by an ID.
    ///
    subscript(objectID: ObjectID) -> ObjectSnapshot? { get }
    
    /// Get objects of given type.
    ///
    func filter(type: ObjectType) -> [ObjectSnapshot]
    
    /// Get distinct values of an attribute.
    func distinctAttribute(_ attributeName: String, ids: some Collection<ObjectID>) -> Set<Variant>

    /// Get distinct object types of a list of objects.
    func distinctTypes(_ ids: some Collection<ObjectID>) -> [ObjectType]

    /// Get shared traits of a list of objects.
    func sharedTraits(_ ids: some Collection<ObjectID>) -> [Trait]
    
    /// Filter IDs and keep only those that are contained in the plane.
    ///
    /// Use this function to sanitise a selection between plane changes, if you want to preserve
    /// the selection between edits.
    ///
    /// - SeeAlso: ``Selection``
    ///
    func existing(from ids: [ObjectID]) -> [ObjectID]
}

// MARK: - Default Implementations

extension Plane {
    public subscript(id: ObjectID) -> ObjectSnapshot? {
        get {
            self.object(id)
        }
    }
    /// Get first object of given type.
    ///
    /// This method is used to find singleton objects, for example
    /// design info object.
    ///
    public func first(type: ObjectType) -> ObjectSnapshot? {
        return snapshots.first { $0.type.matches(type) }
    }
    
    /// Filter snapshots by object type.
    ///
    /// - Note: The type is compared my name matching. See ``ObjectType/matches(_:)-(ObjectType)``
    ///
    public func filter(type: ObjectType) -> [ObjectSnapshot] {
        return snapshots.filter { $0.type.matches(type) }
    }
    
    /// Filter objects with given trait.
    ///
    /// Returns objects that have the specified trait.
    ///
    /// - Note: The trait is compared my name matching. See ``Trait/matches(_:)-(Trait)``
    ///
    public func filter(trait: Trait) -> [ObjectSnapshot] {
        return snapshots.filter {
            $0.type.traits.contains { $0.matches(trait) }
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
    
    public func filter(_ predicate: Predicate) -> [ObjectSnapshot] {
        return snapshots.filter {
            predicate.match($0, in: self)
        }
    }

    public func existing(from ids: [ObjectID]) -> [ObjectID] {
        ids.filter { contains($0) }
    }

    /// Get list of objects that have no parent.
    public func top() -> [ObjectSnapshot] {
        self.filter { $0.parent == nil }
    }
    
    /// Get a list of edges that refer to a node.
    ///
    /// To get edges for multiple nodes use ``dependentEdges(_:)``.
    ///
    public func dependentEdges(_ nodeID: ObjectID) -> [ObjectID] {
        var result: Set<ObjectID> = Set()
        for edge in self.edges {
            if edge.origin == nodeID || edge.target == nodeID {
                result.insert(edge.id)
            }
        }
        return Array(result)
    }
    
    /// Get a list of edges that refer to one of given nodes.
    ///
    /// This is a bulk version of ``dependentEdges(_:)``.
    public func dependentEdges(_ nodeIDs: [ObjectID]) -> [ObjectID] {
        var result: Set<ObjectID> = Set()
        for edge in self.edges {
            for nodeID in nodeIDs {
                if edge.origin == nodeID || edge.target == nodeID {
                    result.insert(edge.id)
                }
            }
        }
        return Array(result)
    }

}

// MARK: - Graph Implementations

extension Plane {
    /// First object with exact name match or with normalised name match.
    ///
    /// If the plane contains multiple objects with the same name,
    /// then one is returned arbitrarily. Plane-level names can not assure uniqueness;
    /// uniqueness is a domain-level concern.
    ///
    /// - Returns: First object found with given name or `nil` if no object
    ///   with the given name exists.
    ///
    /// - Complexity: O(n)
    ///
    public func object(named name: String) -> ObjectSnapshot? {
        // TODO: Add a convenience map [normalised key: [ObjectID]]
        let exactFirst = snapshots.first {
            guard let objectName = $0.name else { return false }
            return objectName == name
        }
        if let exactFirst {
            return exactFirst
        }
        
        let key = NormalizedName.normalize(name)
        return snapshots.first {
            guard let objectName = $0.name else { return false }
            return NormalizedName.normalize(objectName) == key
        }
    }
    
    /// Get an object by a string reference - the string might be an object name
    /// or object ID.
    ///
    /// Matching order:
    ///
    /// 1. Try converting the reference to ID and then try to find object with that ID.
    /// 2. Try exact name match.
    /// 3. Normalise the reference and match to normalising object name.
    ///
    /// - Note: If the plane contains multiple objects with matching name, then the one is
    ///   returned arbitrarily. Subsequent calls do not guarantee that the same object is returned.
    ///
    /// - Complexity: O(n)
    ///
    public func object(stringReference: String) -> ObjectSnapshot? {
        if let id = ObjectID(stringReference), contains(id) {
            return self[id]
        }
        else {
            return object(named: stringReference)
        }
    }
}

// MARK: Distinct queries

extension Plane {
    public func distinctAttribute(_ attributeName: String, ids: some Collection<ObjectID>) -> Set<Variant> {
        // TODO: Use ordered set here
        var values: Set<Variant> = Set()
        for id in ids {
            guard let object = self[id] else { continue }
            if let value = object[attributeName] {
                values.insert(value)
            }
        }
        return values
    }

    /// Get distinct object types of a list of objects.
    ///
    /// IDs that do not have corresponding objects in the plane are ignored.
    ///
    public func distinctTypes(_ ids: some Collection<ObjectID>) -> [ObjectType] {
        var types: [ObjectType] = []
        for id in ids {
            guard let object = self[id] else { continue }
            if types.contains(where: { $0.matches(object.type)}) {
                continue
            }
            else {
                types.append(object.type)
            }
        }
        return types
    }

    /// Get shared traits of a list of objects.
    public func sharedTraits(_ ids: some Collection<ObjectID>) -> [Trait] {
        // TODO: Move this method to metamodel as sharedTraits(_ types: [ObjectType])
        guard ids.count > 0 else { return [] }
        
        let types = self.distinctTypes(ids)
        
        guard !types.isEmpty else { return [] }
        
        var traits = types.first!.traits
        
        for type in types.suffix(from: 1) {
            for trait in traits {
                if type.hasTrait(trait) {
                    continue
                }
                traits.removeAll { $0.matches(trait) }
            }
        }
        return traits
    }

}
