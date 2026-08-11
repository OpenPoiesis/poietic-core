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
