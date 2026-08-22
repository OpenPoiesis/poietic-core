//
//  World.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 09/12/2025.
//

/// Component set to changed or new entities on ``World/setPlane(_:)``
public struct ObjectTouched: TagComponent {
    public typealias Storage = TagComponentStorage<Self>
    // TODO: Documentation
    public init() {}
}

/// References an object snapshot in the design.
///
public struct ObjectReference: Component {
    public let objectID: ObjectID
    public let snapshotID: ObjectSnapshotID

    /// Create anew object reference with given object identities.
    ///
    public init(objectID: ObjectID, snapshotID: ObjectSnapshotID) {
        self.objectID = objectID
        self.snapshotID = snapshotID
    }

    public init(_ snapshot: ObjectSnapshot) {
        self.objectID = snapshot.objectID
        self.snapshotID = snapshot.snapshotID
    }
}

// TODO: Document that entities represent logical object, not snapshot
/// A container for storing and working with run-time entities, components and relationships.
///
/// Functionality:
///
/// - Storage of entities: ``spawn(_:)->RuntimeEntity``, ``despawn(_:)-(RuntimeEntity)``.
/// - Storage and management of components, used through ``RuntimeEntity/setComponent(_:)``,
///   ``RuntimeEntity/component()``
/// - Storage and management of entity relationships, used through ``RuntimeEntity/relate(_:to:)-(_,RuntimeID)``.
/// - Management of systems schedules
/// - Design issue management
///
/// ## World and Design relationship
///
/// World is primarily a runtime instance of a design, specifically of a design plane.
///
/// Setting a design plane creates or updates entities that represent logical objects in the plane.
/// Such entities have ``ObjectReference`` component set on them on creation. The component is
/// updated when there is a new snapshot for given logical object.
///
/// - Note: Entities representing design objects live as long as the logical object
///   (identified by ``ObjectID``) exists in the planes set by ``setPlane(_:)``. Once
///   despawned, new design object representing entities will get new ID, despite having
///   the same `ObjectID` as their previous instances.
///
/// - SeeAlso: ``RuntimeEntity``, ``Component``, ``Relationship``
///
public class World {
    public let design: Design
    public private(set) var plane: DesignPlane?
    
    // Identity
    /// Sequence for generating world entities IDs.
    ///
    /// The IDs exist only during runtime. They should not be persisted.
    ///
    internal var entitySequence: UInt64

    var schedules: [ObjectIdentifier:Schedule]
    
    // TODO: Make issues a component, to unify the interface.
    /// Issues collected during plane processing.
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

    /// List of entities contained in this world.
    ///
    internal var entities: Set<RuntimeID>

    /// Components without an entity.
    ///
    /// Only one component of given type might exist in the world as a singleton.
    ///
    public private(set) var singletons: ComponentSet
    private var componentStorages: [ObjectIdentifier: any ComponentStorageProtocol] = [:]
    internal var relationshipStorages: [ObjectIdentifier: any RelationshipStorageProtocol] = [:]

    /// Creates a new empty world without a plane associated with it.
    ///
    /// - SeeAlso: ``setPlane(_:)``
    ///
    public init(design: Design) {
        self.design = design
        self.entitySequence = 1
        self.schedules = [:]
        self.issues = [:]
        self.entities = Set()
        
        self.objectToEntityMap = [:]
        self.plane = nil
        self.singletons = ComponentSet()
    }
    
    /// Creates a new world and sets the plane. The world will be populated with entities
    /// representing design objects in the plane.
    ///
    /// - SeeAlso: ``setPlane(_:)``
    ///
    public convenience init(plane: DesignPlane) {
        self.init(design: plane.design)
        setPlane(plane)
    }
    
    /// Get an entity that represents an object with given ID, if such entity exists.
    ///
    /// Objects in the ``plane`` are always guaranteed to have an entity that represents them.
    ///
    internal func objectToEntity(_ objectID: ObjectID) -> RuntimeID? {
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
        entity.world === self && self.entities.contains(entity.runtimeID)
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
    }

    /// Runs systems in a schedule.
    ///
    /// Parameters:
    ///     - cleanIntermediates: If true, then when the schedule finishes, singletons of type
    ///       ``IntermediateSingleton`` are removed
    ///
    /// The intermediaries are cleaned up only on successful schedule run.
    ///
    /// - Precondition: The schedule must be registered with the world.
    ///
    public func run(schedule: ScheduleLabel.Type, cleanIntermediates: Bool = true) throws (InternalSystemError) {
        guard let schedule = self.schedules[ObjectIdentifier(schedule)] else {
            preconditionFailure("Unknown schedule \(String(describing: schedule))")
        }
        try schedule.update(self)
        
        if cleanIntermediates {
            removeIntermediateSingletons()
        }
    }
    
    /// Removes all singletons of type ``IntermediateSingleton``.
    ///
    /// - SeeAlso: ``run(schedule:cleanIntermediates:)``.
    ///
    public func removeIntermediateSingletons() {
        // Clean-up intermediaries
        let intermediates: [ObjectIdentifier] = self.singletons.compactMap {
            if $0 is any IntermediateSingleton {
                return ObjectIdentifier(type(of: $0))
            }
            else {
                return nil
            }
        }
        for id in intermediates {
            self.singletons.remove(id)
        }

    }

    /// Set a design plane to be world's current design plane.
    ///
    /// When a new plane is set, the following happens:
    ///
    /// 1. Despawn removed design object – entities representing objects that are not present in
    ///    the new plane.
    ///    See ``despawn(_:)-(RuntimeID)``.
    /// 2. Spawn new entities for new design objects. New design objects are objects with ObjectID
    ///    that are not present in the world.
    /// 3. Set ``ObjectTouched`` tag on changed design object entities – entities that were
    ///    representing objects (by `ObjectID`) in previous and in the new plane, but their
    ///    version snapshot (`ObjectSnapshotID`) has changed.
    /// 4. Clear ``ObjectTouched`` tag on design object entities that remained the same.
    ///
    /// - Note: Incoming relationships such as `RepresentationOf` survive plane changes
    ///   for unchanged and mutated objects.
    ///
    public func setPlane(_ newPlane: DesignPlane) {
        precondition(newPlane.design === self.design)
        precondition(self.design.containsPlane(newPlane.id))
        
        self.removeComponentForAll(ObjectTouched.self)
        var trash: [RuntimeID] = []
        for (objectID, runtimeID) in objectToEntityMap {
            if !newPlane.contains(objectID) {
                trash.append(runtimeID)
            }
        }
        _unsafeDespawn(trash)
        
        for snapshot in newPlane.snapshots {
            if let existing = self.entity(snapshot.objectID) {
                guard let existingRef = _getComponent(ObjectReference.self, for: existing.runtimeID)
                else {
                    preconditionFailure("Object snapshot has no ObjectReference component")
                }
                if existingRef.snapshotID != snapshot.snapshotID {
                    _setComponent(ObjectTouched(), for: existing.runtimeID)
                    _setComponent(ObjectReference(snapshot), for: existing.runtimeID)
                }
            }
            else {
                _spawnDesignObjectEntity(snapshot)
            }
        }
        
        self.plane = newPlane
        self.issues.removeAll()
    }
    
    private func _spawnDesignObjectEntity(_ snapshot: ObjectSnapshot) {
        let entity: RuntimeEntity = spawn(
            ObjectReference(snapshot),
            ObjectTouched(),
        )
        objectToEntityMap[snapshot.objectID] = entity.runtimeID
    }

    public func removePlane() {
        self.plane = nil
        let storage = self.componentStorage(for: ObjectReference.self)
        let trash = Array(storage.ids)
        despawn(trash)
    }
    

    /// Spawn an ephemeral entity.
    ///
    /// - Returns: Entity ID of the spawned entity.
    ///
    public func spawn(_ components: [any Component] = []) -> RuntimeID {
        let value = entitySequence
        entitySequence += 1
        let id = RuntimeID(intValue: value)
        self.entities.insert(id)
        for component in components {
            self._setComponent(component, for: id)
        }
        return id
    }

    public func spawn(_ components: any Component...) -> RuntimeEntity {
        let id = self.spawn(components)
        return RuntimeEntity(runtimeID: id, world: self)
    }
    
    /// Removes the entity from the world and all entities that depend on it.
    ///
    /// The dependants are entities with relationships towards the removed entities where the
    /// relationship removal policy (``Relationship/targetRemovalPolicy``) is
    /// ``RelationshipRemovalPolicy/despawn``.
    ///
    public func despawn(_ id: RuntimeID) {
        self.despawn([id])
    }
    
    /// Despawn a runtime entity.
    ///
    /// Convenience method. See ``despawn(_:)-(RuntimeID)``
    ///
    public func despawn(_ entity: RuntimeEntity) {
        self.despawn([entity.runtimeID])
    }

    /// Despawn in a cascading manner a list of entities from the world, including their dependants.
    ///
    /// The dependants are entities with relationships towards the removed entities where the
    /// relationship removal policy (``Relationship/targetRemovalPolicy``) is
    /// ``RelationshipRemovalPolicy/despawn``.
    ///
    /// - Precondition: Design object entities – entities with ``ObjectReference``
    ///   component – can not be despawned.
    ///
    public func despawn(_ ids: some Sequence<RuntimeID>) {
        let trash = _cascadingDependencies(of: Set(ids))
        for id in trash {
            precondition(!_containsComponent(ObjectReference.self, for: id),
            "Cannot despawn entity representing design object")
        }
        _unsafeDespawn(trash)
    }
    
    internal func _cascadingDependencies(of ids: Set<RuntimeID>) -> Set<RuntimeID> {
        var visited = ids
        var queue = Array(ids)
        
        while !queue.isEmpty {
            let id = queue.removeLast()
            
            for storage in relationshipStorages.values {
                let policy = storage.targetRemovalPolicy

                for originID in storage.dependants(of: id) {
                    guard !visited.contains(originID) else { continue }
                    switch policy {
                    case .despawn:
                        visited.insert(originID)
                        queue.append(originID)
                    case .remove:
                        // No need to do anything, will be removed in defer block.
                        break
                    case .fatalError:
                        fatalError("Dangling relationship")
                    }
                }
            }
        }
        return visited
    }
    
    /// Despawns entities without checking for dependencies.
    ///
    internal func _unsafeDespawn(_ trash: some Sequence<RuntimeID>) {
        for id in trash {
            _remove(id)
        }
        entities.subtract(trash)
    }
    
    private func _remove(_ runtimeID: RuntimeID) {
        if let ref = _getComponent(ObjectReference.self, for: runtimeID){
            objectToEntityMap.removeValue(forKey: ref.objectID)
        }
        _removeAllComponents(for: runtimeID)
        _removeAllRelationships(with: runtimeID)
    }
    // MARK: - Components
    
    internal func componentStorage<T: Component>(for type: T.Type) -> T.Storage {
        let id = ObjectIdentifier(T.self)
        
        if let existing = componentStorages[id] as? T.Storage {
            return existing
        }
        
        guard let newStorage = T.makeStorage() as? T.Storage else {
            fatalError("Invalid storage for component \(String(describing: T.self))")
        }
        componentStorages[id] = newStorage
        return newStorage
    }
    
    /// Count entities with given component.
    public func count<T: Component>(_ type: T.Type) -> Int {
        let storage = componentStorage(for: T.self)
        return storage.count
    }

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
    }
    
    internal func _containsComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) -> Bool {
        let storage = componentStorage(for: T.self)
        return storage.hasComponent(for: runtimeID)
    }
    internal func _getComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) -> T? {
        let storage = componentStorage(for: T.self)
        return storage.component(for: runtimeID)
    }


    internal func _debugComponents(for runtimeID: RuntimeID) -> ComponentSet {
        var components = ComponentSet()
        for storage in componentStorages.values {
            guard let component: any Component = storage.component(for: runtimeID)
            else { continue }
            components.set(component)
        }
        return components
    }

    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - runtimeID: The object ID
    ///
    internal func _removeComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) {
        let componentTypeID = ObjectIdentifier(T.self)
        _removeComponent(componentTypeID, for: runtimeID)
    }
    
    internal func _removeComponent(_ componentTypeID: ObjectIdentifier, for runtimeID: RuntimeID) {
        guard let storage = componentStorages[componentTypeID] else { return }
        storage.removeComponent(for: runtimeID)
    }

    public func removeComponentForAll<T: Component>(_ type: T.Type) {
        let storageTypeID = ObjectIdentifier(type)
        guard let storage = componentStorages[storageTypeID] else { return }
        storage.removeAll()
    }

    /// Remove all components from an entity.
    func _removeAllComponents(for runtimeID: RuntimeID) {
        for storage in componentStorages.values {
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
    
    // MARK: - Relationships

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

    // MARK: - Query
    
    /// Get a list of entities which represent objects from the list.
    ///
    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query(_ ids: some Sequence<ObjectID>) -> QueryResult<RuntimeEntity> {
        let runtimeIDs = ids.compactMap { objectToEntityMap[$0] }
        let result = QueryResult(world: self, ids: runtimeIDs) {
            RuntimeEntity(runtimeID: $1, world: self)
        }
        return result
    }

    /// Get a list of objects with given component.
    ///
    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<RuntimeEntity> {
        let storage = self.componentStorage(for: componentType)

        let result = QueryResult(world: self, ids: storage.ids)  {
            RuntimeEntity(runtimeID: $1, world: self)
        }
        return result
    }

    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<T> {
        let storage = self.componentStorage(for: componentType)
        let result = QueryResult(world: self, ids: storage.ids)  {
            storage.component(for: $1)
        }
        return result
    }

    /// - Complexity: O(n). For now. See ``QueryResult`` for developer comments.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<(RuntimeEntity, T)> {
        let storage = self.componentStorage(for: componentType)

        let result = QueryResult(world: self, ids: storage.ids)  {
            // We can force unwrap, because we are iterating over existing components
            (RuntimeEntity(runtimeID: $1, world: self), storage.component(for: $1)!)
        }
        return result
    }

    /// Queries the world and filters entities which have both specified components.
    ///
    /// - Complexity: O(n) where n is number of entities with `componentType1`.
    /// - Note: It is recommended to use have `componentType1` as a component with small or smaller
    ///   number of entities compared to `componentType2`.
    ///
    public func query<C1: Component, C2: Component>(_ componentType1: C1.Type, _ componentType2: C2.Type) -> QueryResult<(RuntimeEntity, C1, C2)> {
        let storage1 = self.componentStorage(for: componentType1)
        let storage2 = self.componentStorage(for: componentType2)

        let result: QueryResult<(RuntimeEntity, C1, C2)> =
        QueryResult(world: self, ids: storage1.ids) {
            guard let component1 = storage1.component(for: $1),
                  let component2 = storage2.component(for: $1)
            else { return nil }
            return (RuntimeEntity(runtimeID: $1, world: self), component1, component2)
        }
        return result
    }

    // MARK: - Issues

    /// Flag indicating whether any design issues were registered.
    ///
    /// - SeeAlso: ``RuntimeEntity/appendIssue(_:)``, ``RuntimeEntity/issues``
    ///
    public var hasIssues: Bool { !issues.isEmpty }
}
