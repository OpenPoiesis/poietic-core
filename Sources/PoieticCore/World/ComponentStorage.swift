//
//  ComponentStorage.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/02/2026.
//

protocol ComponentStorageProtocol {
    associatedtype ComponentType: Component
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
    private var components: [RuntimeID: ComponentType] = [:]
    
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

    // For iteration over all entities with this component
//    var allEntities: Dictionary<RuntimeID, ComponentType>.Keys {
//        return components.keys
//    }
}
