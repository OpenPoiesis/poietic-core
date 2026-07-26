//
//  RelationshipStorage.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 27/05/2026.
//

typealias ComponentID = ObjectIdentifier

/// Protocol for storage of relationships of a specific ``Relationship`` subtype.
///
/// Each storage instance manages all relationships of a single relationship type (e.g. all
/// ``ChildOf`` relationships in the world). The storage maintains bidirectional indices so that
/// both outgoing queries ("what does entity A point to?") and incoming queries ("who points to
/// entity B?") are O(1).
///
protocol RelationshipStorageProtocol {
    associatedtype RelationshipType: Relationship

    /// Create or replace a relationship from `origin` to `target`.
    ///
    /// If the relationship type has ``Relationship/outgoingCardinality`` of ``Cardinality/one``,
    /// any existing outgoing relationship of this type from `origin` is removed first.
    func setRelationship(from origin: RuntimeID, to target: RuntimeID, component: RelationshipType)

    /// Remove a specific relationship between two entities.
    func removeRelationship(from origin: RuntimeID, to target: RuntimeID)

    /// Returns `true` if the entity has at least one outgoing relationship of this type.
    func hasRelationship(from origin: RuntimeID) -> Bool

    /// Returns `true` if a relationship of this type exists from `origin` to `target`.
    func hasRelationship(from origin: RuntimeID, to target: RuntimeID) -> Bool

    /// Remove all relationships of this type from the storage.
    func removeAll()

    /// Get the relationship component for a specific origin-target pair, if it exists.
    func relationship(from origin: RuntimeID, to target: RuntimeID) -> RelationshipType?

    /// Remove all relationships of this type where `runtimeID` is either the origin or the target.
    ///
    /// Called when an entity is despawned to clean up all relationship edges involving it.
    func removeRelationships(with runtimeID: RuntimeID)

    /// Remove all outgoing relationships of this type from `origin`.
    func removeOutgoing(from origin: RuntimeID)

    /// Get the first outgoing target from `origin`.
    ///
    /// - Precondition: The relationship type must have to-one cardinality
    ///   (``Relationship/outgoingCardinality`` is ``Cardinality/one``). Calling this on a
    ///   to-many relationship is a programming error — the result is non-deterministic.
    func firstOutgoing(from origin: RuntimeID) -> RuntimeID?

    /// The cleanup behaviour for this relationship type when the target entity is removed.
    ///
    /// Derived from ``RelationshipType/targetRemovalPolicy``.
    var targetRemovalPolicy: RelationshipRemovalPolicy { get }

    /// Get IDs of entities that have an incoming relationship of this type to `target`.
    ///
    /// These entities depend on `target`'s existence: when `target` is despawned, each
    /// dependant is handled according to ``targetRemovalPolicy`` (despawned, cleaned up,
    /// or triggers a fatal error).
    ///
    /// - Returns: Origin IDs of all incoming relationships to `target` of this type.
    func dependants(of target: RuntimeID) -> [RuntimeID]
}

extension RelationshipStorageProtocol {
    var targetRemovalPolicy: RelationshipRemovalPolicy { RelationshipType.targetRemovalPolicy }
}

/// Storage for relationship components.
///
/// Relationships are owned by the origin entity. When origin entity is despawned, all its
/// relationships are removed.
final class RelationshipStorage<C: Relationship>: RelationshipStorageProtocol {
    typealias RelationshipType = C

    struct RelationshipKey: Hashable {
        let origin: RuntimeID
        let target: RuntimeID
    }
    
    private var components: [RelationshipKey: RelationshipType] = [:]
    private var outgoingIndex: [RuntimeID: Set<RuntimeID>] = [:]
    private var incomingIndex: [RuntimeID: Set<RuntimeID>] = [:]
    
    func setRelationship(from origin: RuntimeID, to target: RuntimeID, component: RelationshipType) {
        let key = RelationshipKey(origin: origin, target: target)

        if RelationshipType.outgoingCardinality == .one {
            for target in outgoingIndex[origin] ?? [] {
                removeRelationship(from: origin, to: target)
            }
        }
        
        components[key] = component
        outgoingIndex[origin, default: Set()].insert(target)
        incomingIndex[target, default: Set()].insert(origin)
    }
    
    func removeRelationship(from origin: RuntimeID, to target: RuntimeID) {
        let key = RelationshipKey(origin: origin, target: target)
        components[key] = nil
        outgoingIndex[origin, default: Set()].remove(target)
        incomingIndex[target, default: Set()].remove(origin)
    }

    /// Remove all relationships where the ``runtimeID`` is either origin or a target
    func removeRelationships(with runtimeID: RuntimeID) {
        for target in outgoingIndex[runtimeID] ?? [] {
            removeRelationship(from: runtimeID, to: target)
        }
        for origin in incomingIndex[runtimeID] ?? [] {
            removeRelationship(from: origin, to: runtimeID)
        }
    }

    func removeOutgoing(from origin: RuntimeID) {
        for target in outgoingIndex[origin] ?? [] {
            removeRelationship(from: origin, to: target)
        }
    }

    func hasRelationship(from origin: RuntimeID, to target: RuntimeID) -> Bool {
        let key = RelationshipKey(origin: origin, target: target)
        return components[key] != nil
    }
    func hasRelationship(from origin: RuntimeID) -> Bool {
        if let outgoing = outgoingIndex[origin] {
            return !outgoing.isEmpty
        }
        else {
            return false
        }
    }
//    func hasAnyRelationship(from origin: RuntimeID) -> Bool {
//        return outgoingIndex[origin] != nil
//    }
//    func hasAnyRelationship(to target: RuntimeID) -> Bool {
//        return incomingIndex[target] != nil
//    }
    func removeAll() {
        components.removeAll()
        outgoingIndex.removeAll()
        incomingIndex.removeAll()
    }

    func relationship(from origin: RuntimeID, to target: RuntimeID) -> RelationshipType? {
        let key = RelationshipKey(origin: origin, target: target)
        return components[key]
    }
    
    func incoming(to target: RuntimeID) -> [(RuntimeID, RelationshipType)] {
        var result: [(RuntimeID, RelationshipType)] = []
        for origin in incomingIndex[target, default: []] {
            let key = RelationshipKey(origin: origin, target: target)
            if let component = components[key] {
                result.append((origin, component))
            }
        }
        return result
    }

    func outgoing(from origin: RuntimeID) -> [(RuntimeID, RelationshipType)] {
        var result: [(RuntimeID, RelationshipType)] = []
        for target in outgoingIndex[origin, default: []] {
            let key = RelationshipKey(origin: origin, target: target)
            if let component = components[key] {
                result.append((target, component))
            }
        }
        return result
    }
    func outgoing(from origin: RuntimeID) -> [RuntimeID] {
        return Array(outgoingIndex[origin, default: []])
    }

    func firstOutgoing(from origin: RuntimeID) -> RuntimeID? {
        return outgoingIndex[origin]?.first
    }

    func dependants(of target: RuntimeID) -> [RuntimeID] {
        return Array(incomingIndex[target, default: []])
    }

}

extension World {
    private func relationshipStorage<T: Relationship>(for type: T.Type) -> RelationshipStorage<T> {
        let id = ObjectIdentifier(T.self)
        
        if let existing = relationshipStorages[id] as? RelationshipStorage<T> {
            return existing
        }
        
        let newStorage = RelationshipStorage<T>()
        relationshipStorages[id] = newStorage
        return newStorage
    }

    internal func _setRelationship<T: Relationship>(_ component: T,
                                                    from originID: RuntimeID,
                                                    to targetID: RuntimeID)
    {
        precondition(entities.contains(originID))
        precondition(entities.contains(targetID))

        let storage = relationshipStorage(for: T.self)
        storage.setRelationship(from: originID, to: targetID, component: component)
    }
    internal func _getFirstTarget<T: Relationship>(_ componentType: T.Type,
                                                    from originID: RuntimeID) -> RuntimeID?
    {
        precondition(entities.contains(originID))

        let storage = relationshipStorage(for: T.self)
        return storage.firstOutgoing(from: originID)
    }
    internal func _removeRelationship<T: Relationship>(_ type: T.Type,
                                                       from origin: RuntimeID,
                                                       to target: RuntimeID)
    {
        let typeID = ObjectIdentifier(T.self)
        _removeRelationship(typeID, from: origin, to: target)
    }

    internal func _removeRelationship(_ typeID: ObjectIdentifier,
                                      from origin: RuntimeID,
                                      to target: RuntimeID)
    {
        guard let storage = relationshipStorages[typeID] else { return }

        storage.removeRelationship(from: origin, to: target)
    }
    
    internal func _removeAllRelationships<T: Relationship>(_ type: T.Type,
                                                            from origin: RuntimeID) {
        guard let storage = relationshipStorages[ObjectIdentifier(T.self)] else { return }
        storage.removeOutgoing(from: origin)
    }

    /// Remove all relationships where the ``runtimeID`` is either origin or a target.
    func _removeAllRelationships(with runtimeID: RuntimeID) {
        for storage in relationshipStorages.values {
            storage.removeRelationships(with: runtimeID)
        }
    }

    public func _containsRelationship<T: Relationship>(_ type: T.Type, from origin: RuntimeID) -> Bool {
        let storageTypeID = ObjectIdentifier(type)
        guard let storage = relationshipStorages[storageTypeID] else { return false }
        return storage.hasRelationship(from: origin)
    }
    
    public func _containsRelationship<T: Relationship>(_ type: T.Type, from origin: RuntimeID, to target: RuntimeID) -> Bool {
        let storageTypeID = ObjectIdentifier(type)
        guard let storage = relationshipStorages[storageTypeID] else { return false }
        return storage.hasRelationship(from: origin, to: target)
    }

    public func removeRelationshipForAll<T: Relationship>(_ type: T.Type) {
        let storageTypeID = ObjectIdentifier(type)
        guard let storage = relationshipStorages[storageTypeID] else { return }
        storage.removeAll()
    }

    internal func incoming<T: Relationship>(_ componentType: T.Type, to target: RuntimeID) -> [(RuntimeEntity, T)] {
        let storage = relationshipStorage(for: T.self)
        return storage.incoming(to: target).map { (id, component) in
            (RuntimeEntity(runtimeID: id, world: self), component)
        }
    }
    internal func outgoing<T: Relationship>(_ componentType: T.Type, from origin: RuntimeID) -> [(RuntimeEntity, T)] {
        let storage = relationshipStorage(for: T.self)
        return storage.outgoing(from: origin).map { (id, component) in
            (RuntimeEntity(runtimeID: id, world: self), component)
        }
    }
//    internal func _containsRelationship<T: Relationship>(_ component: T,
//                                                         from originID: RuntimeID,
//                                                         to targetID: RuntimeID) -> Bool
//    {
//        let storage = componentStorage(for: T.self)
//        return storage.hasComponent(for: runtimeID)
//    }
}

extension RuntimeEntity {
    
    // TODO: Rename to relate(as:to:)
    public func relate<T: Relationship>(_ component: T, to targetID: RuntimeID) {
        world._setRelationship(component, from: self.runtimeID, to: targetID)
    }
    public func relate<T: Relationship>(_ component: T, to target: RuntimeEntity) {
        world._setRelationship(component, from: self.runtimeID, to: target.runtimeID)
    }

    /// Remove all outgoing relationships of the given type from this entity.
    public func unrelate<T: Relationship>(_ type: T.Type) {
        world._removeAllRelationships(T.self, from: runtimeID)
    }

    /// Remove a specific relationship to a target entity.
    public func unrelate<T: Relationship>(_ type: T.Type, to target: RuntimeEntity) {
        world._removeRelationship(T.self, from: runtimeID, to: target.runtimeID)
    }

    public func target<T: Relationship>(_ componentType: T.Type) -> RuntimeID? {
        world._getFirstTarget(T.self, from: self.runtimeID)
    }
    public func target<T: Relationship>(_ componentType: T.Type) -> RuntimeEntity? {
        if let target = world._getFirstTarget(T.self, from: self.runtimeID) {
            return RuntimeEntity(runtimeID: target, world: self.world)
        }
        else {
            return nil
        }
    }
    public func relates<T: Relationship>(_ type: T.Type) -> Bool {
        world._containsRelationship(type, from: self.runtimeID)
    }

    public func relates<T: Relationship>(_ type: T.Type, to targetID: RuntimeID) -> Bool {
        world._containsRelationship(type, from: self.runtimeID, to: targetID)
    }
    public func relates<T: Relationship>(_ type: T.Type, to entity: RuntimeEntity) -> Bool {
        world._containsRelationship(type, from: self.runtimeID, to: entity.runtimeID)
    }

    @available(*, deprecated, renamed: "relates")
    public func containsRelationship<T: Relationship>(_ type: T.Type) -> Bool {
        world._containsRelationship(type, from: self.runtimeID)
    }

    @available(*, deprecated, renamed: "relates")
    public func containsRelationship<T: Relationship>(_ type: T.Type, to targetID: RuntimeID) -> Bool {
        world._containsRelationship(type, from: self.runtimeID, to: targetID)
    }

    /// List of entity children – entities with ``ChildOf`` relationship component pointing
    /// to this entity.
    ///
    /// This is a convenience property that uses incoming relationships of the entity.
    ///
    public var children: [RuntimeEntity] {
        return world.incoming(ChildOf.self, to: self.runtimeID).map { $0.0 }
    }

    /// Get a parent of an entity. Parent is defined by the target of the ``ChildOf`` relationship.
    ///
    /// This is a convenience property that uses outgoing relationships of the entity.
    ///
    public var parent: RuntimeEntity? {
        guard let target = world._getFirstTarget(ChildOf.self, from: self.runtimeID)
        else { return nil }
        
        return RuntimeEntity(runtimeID: target, world: self.world)
    }
        
    /// Get origin entities of given relationships where the target is this entity.
    ///
    /// Example:
    ///
    /// ```
    /// let node: RuntimeEntity // Assuming this exists
    /// let children: [RuntimeEntity] = node.incoming(ChildOf.self)
    /// let representations: [RuntimeEntity] = node.incoming(RepresentationOf.self)
    /// ```
    ///
    public func incoming<T: Relationship>(_ type: T.Type) -> [RuntimeEntity] {
        return world.incoming(T.self, to: self.runtimeID).map { $0.0 }
    }

    /// Get target entities of given relationships where the origin is this entity.
    public func outgoing<T: Relationship>(_ type: T.Type) -> [RuntimeEntity] {
        return world.outgoing(T.self, from: self.runtimeID).map { $0.0 }
    }
    
    /// Get first outgoing relationship of given type.
    ///
    /// - Precondition: The relationship type cardinality ``Relationship/outgoingCardinality`` must
    /// be to-one (``Cardinality/one``). It is considered a programming error to call this
    /// function on to-many relationship.
    ///
    public func firstOutgoing<T: Relationship>(_ type: T.Type) -> RuntimeEntity? {
        precondition(type.outgoingCardinality == .one)
        
        let outgoings = world.outgoing(T.self, from: self.runtimeID)
        return outgoings.first.map { $0.0 }
    }
}
