//
//  ComponentStorage.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/02/2026.
//

public protocol ComponentStorageProtocol<ComponentType> {
    associatedtype ComponentType: Component
    associatedtype IDCollection: Collection<RuntimeID>

    /// Number of entities with given component in the storage
    var count: Int { get }
    
    /// Snapshot collection of IDs that is to be consumed immediately.
    ///
    /// - Important: Do not store the values.
    ///
    var ids: IDCollection { get }

    func hasComponent(for entity: RuntimeID) -> Bool
    func component(for runtimeID: RuntimeID) -> ComponentType?
    func setComponent(_ component: ComponentType, for runtimeID: RuntimeID)

    func removeComponent(for entity: RuntimeID)
    func removeAll()
    func relationship(for runtimeID: RuntimeID) -> (any Relationship)?
}

extension ComponentStorageProtocol {
    public func relationship(for runtimeID: RuntimeID) -> (any Relationship)? {
        return nil
    }
}

extension ComponentStorageProtocol where ComponentType: Relationship {
    func relationship(for runtimeID: RuntimeID) -> (any Relationship)? {
        return component(for: runtimeID)
    }
}

public final class DictionaryComponentStorage<C: Component>: ComponentStorageProtocol {
    
    public typealias ComponentType = C
    public typealias IDCollection = [RuntimeID: ComponentType].Keys
    private var components: [RuntimeID: ComponentType] = [:]

    public var count: Int { components.count }
    
    public var ids: IDCollection {
        return components.keys
    }
    
    public func setComponent(_ component: ComponentType, for runtimeID: RuntimeID)
    {
        components[runtimeID] = component
    }
    
    public func component(for runtimeID: RuntimeID) -> ComponentType? {
        return components[runtimeID]
    }
    
    public func removeComponent(for runtimeID: RuntimeID) {
        components.removeValue(forKey: runtimeID)
    }

    public func removeAll() {
        components.removeAll()
    }

    public func hasComponent(for runtimeID: RuntimeID) -> Bool {
        return components[runtimeID] != nil
    }
}

public final class TagComponentStorage<C: Component>: ComponentStorageProtocol {
    
    public typealias ComponentType = C
    public typealias IDCollection = Set<RuntimeID>
    private var entities: Set<RuntimeID> = Set()

    // To not to have circular reference (C: TagComponent)
    
    private let factory: () -> C
    init(factory: @escaping () -> C ) {
        self.factory = factory
    }
    
    public var count: Int { entities.count }
    
    public var ids: IDCollection {
        return entities
    }
    
    public func setComponent(_ component: ComponentType, for runtimeID: RuntimeID)
    {
        entities.insert(runtimeID)
    }
    
    public func component(for runtimeID: RuntimeID) -> ComponentType? {
        if entities.contains(runtimeID) {
            return factory()
        }
        else {
            return nil
        }
    }
    
    public func removeComponent(for runtimeID: RuntimeID) {
        entities.remove(runtimeID)
    }

    public func removeAll() {
        entities.removeAll()
    }

    public func hasComponent(for runtimeID: RuntimeID) -> Bool {
        return entities.contains(runtimeID)
    }
}

extension TagComponentStorage where C: TagComponent {
    public convenience init() {
        self.init(factory: { C() })
    }
}
