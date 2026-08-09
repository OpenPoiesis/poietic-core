//
//  ComponentStorage.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/02/2026.
//

public protocol ComponentStorageProtocol {
    associatedtype ComponentType: Component
    associatedtype IDCollection: Collection<RuntimeID>

    /// Number of entities with given component in the storage
    var count: Int { get }
    
    /// Snapshot collection of IDs that is to be consumed immediately.
    ///
    /// - Important: Do not store the values.
    ///
    var ids: IDCollection { get }

    func removeComponent(for entity: RuntimeID)
    func hasComponent(for entity: RuntimeID) -> Bool
    func removeAll()
    func component(for runtimeID: RuntimeID) -> ComponentType?
    func relationship(for runtimeID: RuntimeID) -> (any Relationship)?
}

extension ComponentStorageProtocol {
    func relationship(for runtimeID: RuntimeID) -> (any Relationship)? {
        return nil
    }
}

extension ComponentStorageProtocol where ComponentType: Relationship {
    func relationship(for runtimeID: RuntimeID) -> (any Relationship)? {
        return component(for: runtimeID)
    }
}

final class ComponentStorage<C: Component>: ComponentStorageProtocol {
    
    typealias ComponentType = C
    typealias IDCollection = [RuntimeID: ComponentType].Keys
    private var components: [RuntimeID: ComponentType] = [:]

    var count: Int { components.count }
    
    var ids: IDCollection {
        return components.keys
    }
    
    func setComponent(_ component: ComponentType, for runtimeID: RuntimeID)
    {
        components[runtimeID] = component
    }
    
    func component(for runtimeID: RuntimeID) -> ComponentType? {
        return components[runtimeID]
    }
    
    func removeComponent(for runtimeID: RuntimeID) {
        components.removeValue(forKey: runtimeID)
    }

    func removeAll() {
        components.removeAll()
    }

    func hasComponent(for runtimeID: RuntimeID) -> Bool {
        return components[runtimeID] != nil
    }
}
