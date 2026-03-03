//
//  World.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 09/12/2025.
//

/// A container for storing and working with run-time entities and components.
///
/// Functionality:
///
/// - storage and management of components
/// - management of systems schedules
/// - design issue management
///
public class World {
    public let design: Design
    // FIXME: Rename to currentFrame
    
    public private(set) var frame: DesignFrame?
    
    // Identity
    /// Sequence for generating world entities IDs.
    ///
    /// The IDs exist only during runtime. They should not be persisted.
    ///
    internal var entitySequence: UInt64

    var schedules: [ObjectIdentifier:Schedule]
    var scheduleLabels: [ObjectIdentifier:String]
    
    // TODO: Make issues a component, to unify the interface.
    // TODO: Make a special error protocol conforming to custom str convertible and having property 'hint:String'
    /// Issues collected during frame processing.
    ///
    /// These are non-fatal issues that indicate problems with the design - with the user data.
    /// The issues are intended to be displayed to the user, preferably
    /// within a context of the object which the issue is associated with.
    ///
    /// Issue list is analogous to a list of syntax errors that were encountered during a
    /// programming language source code compilation.
    ///
    /// Only design objects can have issues associated with it. Non-design objects can not be
    /// created by the users, therefore associating issues with them is not only unhelpful but
    /// also meaningless. Users can act only on objects they created.
    ///
    public internal(set) var issues: [ObjectID: [Issue]]
    
    internal var objectToEntityMap: [ObjectID:RuntimeID]
    internal var entityToObjectMap: [RuntimeID:ObjectID]
    /// Entity ID representing current frame.
    ///
    internal var entities: [RuntimeID]

    /// Components without an entity.
    ///
    /// Only one component of given type might exist in the world as a singleton.
    ///
    public private(set) var singletons: ComponentSet
    private var storages: [ObjectIdentifier: any ComponentStorageProtocol] = [:]

    struct Dependant: Hashable {
        /// Who is pointing at the target?
        let sourceID: RuntimeID
        /// Component that is pointing to the source
        let componentTypeID: ObjectIdentifier
        let removalPolicy: RemovalPolicy
    }
    
    /// Dependencies between entities based on relationships.
    ///
    /// Keys are entities that other entities depend on, values are sets of dependants.
    /// When an entity is de-spawned from the world all its dependants are de-spawned cascadingly.
    ///
    /// - SeeAlso: ``Relationship``, ``ChildOf``, ``OwnedBy``
    ///
    var dependencies: [RuntimeID:Set<Dependant>]
//    var dependencies: [RuntimeID:[RuntimeID:(ObjectIdentifier, RemovalPolicy)]]

    public init(design: Design) {
        self.design = design
        self.entitySequence = 1
        self.schedules = [:]
        self.scheduleLabels = [:]
        self.dependencies = [:]
        self.issues = [:]
        self.entities = []
        
        self.objectToEntityMap = [:]
        self.entityToObjectMap = [:]
        self.frame = nil
        self.singletons = ComponentSet()
    }
    
    public convenience init(frame: DesignFrame) {
        self.init(design: frame.design)
        setFrame(frame)
    }
    
    /// Get an object ID for an object the entity represents, if the object exists in the current
    /// world frame.
    ///
    /// Objects in the ``frame`` are always guaranteed to have an entity that represents them.
    ///
    public func entityToObject(_ ephemeralID: RuntimeID) -> ObjectID? {
        // TODO: [REFACTORING] Rename to runtimeToObject
        entityToObjectMap[ephemeralID]
    }
    /// Get an entity that represents an object with given ID, if such entity exists.
    ///
    /// Objects in the ``frame`` are always guaranteed to have an entity that represents them.
    ///
    public func objectToEntity(_ objectID: ObjectID) -> RuntimeID? {
        // TODO: [REFACTORING] Rename to objectToRuntime
        objectToEntityMap[objectID]
    }

    /// Test whether the world contains an entity with given ID.
    ///
    public func contains(_ id: RuntimeID) -> Bool {
        self.entities.contains(id)
    }
    /// Test whether the world contains an entity.
    ///
    public func contains(_ entity: RuntimeEntity) -> Bool {
        self.entities.contains(entity.runtimeID)
    }
    
    
    public func entity(_ runtimeID: RuntimeID) -> RuntimeEntity? {
        guard self.entities.contains(runtimeID) else { return nil }
        return RuntimeEntity(runtimeID: runtimeID, world: self)
    }

    public func entity(_ objectID: ObjectID) -> RuntimeEntity? {
        guard let runtimeID = objectToEntityMap[objectID] else { return nil }
        return RuntimeEntity(runtimeID: runtimeID, world: self)
    }

    public func addSchedule(_ schedule: Schedule) {
        let id = ObjectIdentifier(schedule.label)
        self.schedules[id] = schedule
        self.scheduleLabels[id] = String(describing: schedule.label)
    }
    
    public func run(schedule: ScheduleLabel.Type) throws (InternalSystemError) {
        guard let schedule = self.schedules[ObjectIdentifier(schedule)] else {
            preconditionFailure("Unknown schedule \(String(describing: schedule))")
        }
        try schedule.update(self)
    }

    /// Set a design frame to be world's current design frame.
    ///
    /// When a new frame is set, the following happens:
    ///
    /// 1. Entity representing the previously set frame and its objects are despawned.
    ///    See ``despawn(_:)-(RuntimeID)``.
    /// 2. New entity for the frame is spawned.
    /// 3. New entities are spawned for design objects from the new frame. The entities are set
    ///    as dependants on the frame.
    /// 4. All issues are cleared.
    ///
    /// - Note: Each time ``setFrame(_:)`` is called a new frame entity is created and the old one
    ///   is despawned, even if the frame has been set in the past. The frame entity is not stored
    ///   and therefore not reused.
    ///
    public func setFrame(_ newFrame: DesignFrame) {
        precondition(newFrame.design === self.design)
        precondition(self.design.containsFrame(newFrame.id))
        
        removeFrameObjectEntities()
        self.frame = newFrame
        spawnFrameObjectEntities()
        self.issues.removeAll()
    }
    
    internal func removeFrameObjectEntities() {
        despawn(entityToObjectMap.keys)
        objectToEntityMap.removeAll()
        entityToObjectMap.removeAll()
    }
    
    internal func spawnFrameObjectEntities() {
        guard let frame
        else { return }
        
        for objectID in frame.objectIDs {
            let runtimeID: RuntimeID = spawn()
            objectToEntityMap[objectID] = runtimeID
            entityToObjectMap[runtimeID] = objectID
        }
    }

    /// Spawn an ephemeral entity.
    ///
    /// - Returns: Entity ID of the spawned entity.
    ///
    public func spawn(_ components: [any Component]) -> RuntimeID {
        let value = entitySequence
        entitySequence += 1
        let id = RuntimeID(intValue: value)
        self.entities.append(id)
        for component in components {
            self._setComponent(component, for: id)
        }
        return id
    }

    public func spawn(_ components: any Component...) -> RuntimeID {
        // TODO: Use lock once we are multi-thread ready (we are not)
        return self.spawn(components)
    }

    public func spawn(_ components: any Component...) -> RuntimeEntity {
        let id = self.spawn(components)
        return RuntimeEntity(runtimeID: id, world: self)
    }
    
    /// Removes the entity from the world and all entities that depend on it.
    ///
    /// Only ephemeral entities can be de-spawned. Persistent design objects can not be de-spawned
    /// from the world.
    ///
    public func despawn(_ id: RuntimeID) {
        self.despawn([id])
    }
    public func despawn(_ entity: RuntimeEntity) {
        self.despawn([entity.runtimeID])
    }

    public func despawn(_ ids: some Sequence<RuntimeID>) {
        var trash: Set<RuntimeID> = Set(ids)
        guard !trash.isEmpty else { return }
        
        var removed: Set<RuntimeID> = []
        
        while !trash.isEmpty {
            let id = trash.removeFirst()
            removed.insert(id)
            defer {
                _removeAllComponents(for: id)
            }
            
            guard let dependants = self.dependencies[id] else { continue }
            
            for dependant in dependants {
                guard !removed.contains(dependant.sourceID) && !trash.contains(dependant.sourceID)
                else { continue }
                
                switch dependant.removalPolicy {
                case .removeSelf:
                    trash.insert(dependant.sourceID)
                case .removeRelationship:
                    self._removeComponent(dependant.componentTypeID, for: dependant.sourceID)
                case .none:
                    break
                }
            }
        }
        entities.removeAll { removed.contains($0) }
    }
    
    // MARK: - Components
    /// Set a component for an entity.
    ///
    /// If a component of the same type already exists for this object,
    /// it will be replaced.
    ///
    /// - Parameters:
    ///   - component: The component to set
    ///   - runtimeID: The object ID
    ///
    /// - Precondition: Entity must exist in the world.
    ///
    internal func _setComponent<T: Component>(_ component: T, for runtimeID: RuntimeID) {
        precondition(entities.contains(runtimeID))

        let storage = componentStorage(for: T.self)
        storage.setComponent(component, for: runtimeID)

        if let rship = component as? Relationship {
            let type = type(of: rship)
            let dep = Dependant(sourceID: runtimeID,
                                componentTypeID: ObjectIdentifier(type),
                                removalPolicy: type.removalPolicy)
            dependencies[rship.target, default: Set()].insert(dep)
        }
    }
    
    internal func _containsComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) -> Bool {
        let storage = componentStorage(for: T.self)
        return storage.hasComponent(for: runtimeID)
    }
    internal func _getComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) -> T? {
        let storage = componentStorage(for: T.self)
        return storage.component(for: runtimeID)
    }

    private func componentStorage<T: Component>(for type: T.Type) -> ComponentStorage<T> {
        let id = ObjectIdentifier(T.self)
        
        if let existing = storages[id] as? ComponentStorage<T> {
            return existing
        }
        
        let newStorage = ComponentStorage<T>()
        storages[id] = newStorage
        return newStorage
    }

    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - runtimeID: The object ID
    ///
    public func _removeComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) {
        let componentTypeID = ObjectIdentifier(T.self)
        _removeComponent(componentTypeID, for: runtimeID)
    }
    
    public func _removeComponent(_ componentTypeID: ObjectIdentifier, for runtimeID: RuntimeID) {
        guard let storage = storages[componentTypeID] else { return }

        if let relationship = storage.relationship(for: runtimeID)
        {
            let removalPolicy = type(of: relationship).removalPolicy
            let item = Dependant(sourceID: runtimeID,
                                 componentTypeID: componentTypeID,
                                 removalPolicy: removalPolicy)
            dependencies[relationship.target, default: Set()].remove(item)
        }

        storage.removeComponent(for: runtimeID)
    }

    public func removeComponentForAll<T: Component>(_ type: T.Type) {
        let storageTypeID = ObjectIdentifier(type)
        guard let storage = storages[storageTypeID] else { return }
        storage.removeAll()
    }

    /// Remove all components from an entity.
    func _removeAllComponents(for runtimeID: RuntimeID) {
        for storage in storages.values {
            storage.removeComponent(for: runtimeID)
        }
    }

    /// Set singleton component – a component without an entity.
    ///
    public func setSingleton<T: Component>(_ component: T) {
        singletons.set(component)
    }

    public func removeSingleton<T: Component>(_ component: T.Type) {
        singletons.remove(component)
    }

    /// Get a singleton component - a component without an entity.
    public func singleton<T: Component>() -> T? {
        return singletons[T.self]
    }
    
    /// Check whether the world contains a singleton.
    ///
    public func hasSingleton<T: Component>(_ component: T.Type) -> Bool{
        singletons.has(component)
    }

    // MARK: - Query
    /// Get a list of entities which represent objects from the list.
    ///
    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query(_ ids: some Sequence<ObjectID>) -> QueryResult<RuntimeEntity> {
        let runtimeIDs = ids.compactMap { objectToEntityMap[$0] }
        return QueryResult(world: self, iterator: runtimeIDs.makeIterator()) { entity in
            guard entity.objectID != nil else { return nil }
            return entity
        }
    }

    // FIXME: Make the query(...) methods use the ComponentStorage. Current implementation is a historical remnant.
    /// Get a list of objects with given component.
    ///
    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<RuntimeEntity> {
        return QueryResult(world: self) { entity in
            guard entity.contains(T.self) else { return nil }
            return entity
        }
    }
    
    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<T> {
        return QueryResult(world: self) { entity in
            return entity[T.self]
        }
    }

    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<(RuntimeEntity, T)> {
        return QueryResult(world: self) { entity in
            guard let comp: T = entity[T.self] else {
                return nil
            }
            return (entity, comp)
        }
    }

    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<C1: Component, C2: Component>(_ componentType1: C1.Type, _ componentType2: C2.Type) -> QueryResult<(RuntimeEntity, C1, C2)> {
        return QueryResult(world: self) { entity in
            guard let comp1: C1 = entity[C1.self],
                  let comp2: C2 = entity[C2.self]
            else { return nil }
            return (entity, comp1, comp2)
        }
    }

    // MARK: - Issues

    /// Flag indicating whether any issues were collected
    public var hasIssues: Bool { !issues.isEmpty }

    @available(*, deprecated, message: "Use entity")
    public func objectHasIssues(_ objectID: ObjectID) -> Bool {
        guard let issues = self.issues[objectID] else { return false }
        return issues.isEmpty
    }

    @available(*, deprecated, message: "Use entity")
    public func objectIssues(_ objectID: ObjectID) -> [Issue]? {
        guard let issues = self.issues[objectID], !issues.isEmpty else { return nil }
        return issues
        
    }
    
    /// Append a user-facing issue for a specific object
    ///
    /// Issues are non-fatal problems with user data. Systems should append
    /// issues here rather than throwing errors, allowing processing to continue
    /// and collect multiple issues.
    ///
    /// - Parameters:
    ///   - issue: The error/issue to append
    ///   - objectID: The object ID associated with the issue
    ///
    @available(*, deprecated, message: "Use entity")
    public func appendIssue(_ issue: Issue, for objectID: ObjectID) {
        issues[objectID, default: []].append(issue)
    }
}
