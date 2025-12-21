//
//  Frame.swift
//
//
//  Created by Stefan Urbanek on 13/02/2023.
//

/// Protocol for version frames.
///
/// Fame Base is a protocol for all version frame types: ``TransientFrame`` and
/// ``DesignFrame``
///
public protocol Frame:
    GraphProtocol where NodeKey == ObjectID,
                        EdgeKey == ObjectID,
                        Edge == DesignObjectEdge {
    /// Design to which the frame belongs.
    var design: Design { get }
    
    var id: FrameID { get }
    
    /// Get a list of all snapshots in the frame.
    ///
    var snapshots: [ObjectSnapshot] { get }
    
    /// Get a list of object IDs in the frame.
    var objectIDs: [ObjectID] { get }

    /// Check whether the frame contains an object with given ID.
    ///
    /// - Returns: `true` if the frame contains the object, otherwise `false`.
    ///
    func contains(_ objectID: ObjectID) -> Bool
    
    /// Return an object with given ID from the frame or `nil` if the frame
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
    func distinctAttribute(_ attributeName: String, ids: [ObjectID]) -> Set<Variant>

    /// Get distinct object types of a list of objects.
    func distinctTypes(_ ids: [ObjectID]) -> [ObjectType]

    /// Get shared traits of a list of objects.
    func sharedTraits(_ ids: [ObjectID]) -> [Trait]
    
    /// Filter IDs and keep only those that are contained in the frame.
    ///
    /// Use this function to sanitise a selection between frame changes, if you want to preserve
    /// the selection between edits.
    ///
    /// - SeeAlso: ``Selection``
    ///
    func existing(from ids: [ObjectID]) -> [ObjectID]
}

// MARK: - Default Implementations

extension Frame {
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

// MARK: Distinct queries

extension Frame {
    public func distinctAttribute(_ attributeName: String, ids: [ObjectID]) -> Set<Variant> {
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
    /// IDs that do not have corresponding objects in the frame are ignored.
    ///
    public func distinctTypes(_ ids: [ObjectID]) -> [ObjectType] {
        var types: [ObjectType] = []
        for id in ids {
            guard let object = self[id] else { continue }
            if types.contains(where: { $0 === object.type}) {
                continue
            }
            else {
                types.append(object.type)
            }
        }
        return types
    }

    /// Get shared traits of a list of objects.
    public func sharedTraits(_ ids: [ObjectID]) -> [Trait] {
        // TODO: Move this method to metamodel as sharedTraits(_ types: [ObjectType])
        guard ids.count > 0 else {
            return []
        }
        
        let types = self.distinctTypes(ids)
        
        var traits = types.first!.traits
        
        for type in types.suffix(from: 1) {
            for trait in traits {
                if type.hasTrait(trait) {
                    continue
                }
                traits.removeAll { $0 === trait }
            }
        }
        return traits
    }

}
