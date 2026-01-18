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
    let design: Design
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
    public private(set) var issues: [ObjectID: [Issue]]
    
    internal var objectToEntityMap: [ObjectID:RuntimeID]
    internal var entityToObjectMap: [RuntimeID:ObjectID]
    /// Entity ID representing current frame.
    ///
    internal var entities: [RuntimeID]
    private var components: [RuntimeID: ComponentSet]

    /// Components without an entity.
    ///
    /// Only one component of given type might exist in the world as a singleton.
    ///
    public private(set) var singletons: ComponentSet

    /// Existential dependencies between entities.
    ///
    /// Keys are entities that other entities depend on, values are sets of dependants.
    /// When an entity is de-spawned from the world all its dependants are de-spawned cascadingly.
    ///
    var dependencies: [RuntimeID:Set<RuntimeID>]

    public init(design: Design) {
        self.design = design
        self.entitySequence = 1
        self.schedules = [:]
        self.scheduleLabels = [:]
        self.dependencies = [:]
        self.components = [:]
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
        entityToObjectMap[ephemeralID]
    }
    /// Get an entity that represents an object with given ID, if such entity exists.
    ///
    /// Objects in the ``frame`` are always guaranteed to have an entity that represents them.
    ///
    public func objectToEntity(_ objectID: ObjectID) -> RuntimeID? {
        objectToEntityMap[objectID]
    }

    /// Test whether the world contains an entity with given ID.
    ///
    public func contains(_ id: RuntimeID) -> Bool {
        self.entities.contains(id)
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
            let runtimeID = spawn()
            objectToEntityMap[objectID] = runtimeID
            entityToObjectMap[runtimeID] = objectID
        }
    }

    /// Spawn an ephemeral entity.
    ///
    /// - Returns: Entity ID of the spawned entity.
    ///
    public func spawn(_ components: any Component...) -> RuntimeID {
        // TODO: Use lock once we are multi-thread ready (we are not)
        let value = entitySequence
        entitySequence += 1
        let id = RuntimeID(intValue: value)
        self.components[id] = ComponentSet(components)
        self.entities.append(id)
        return id
    }
    
    /// Removes the entity from the world and all entities that depend on it.
    ///
    /// Only ephemeral entities can be de-spawned. Persistent design objects can not be de-spawned
    /// from the world.
    ///
    public func despawn(_ id: RuntimeID) {
        self.despawn([id])
    }
    public func despawn(_ ids: some Sequence<RuntimeID>) {
        var trash: Set<RuntimeID> = Set(ids)
        var removed: Set<RuntimeID> = Set()
        
        while !trash.isEmpty {
            let id = trash.removeFirst()
            
            if let objectID = entityToObjectMap.removeValue(forKey: id) {
                objectToEntityMap[objectID] = nil
            }
            
            removed.insert(id)
            if let dependants = dependencies.removeValue(forKey: id) {
                let remaining = dependants.subtracting(removed)
                trash.formUnion(remaining)
            }
            components[id] = nil
            entities.removeAll { $0 == id }
        }
    }
    // MARK: - Dependencies
    /// Make existence of an entity `dependant` dependent on entity `master`.
    ///
    /// When entity `master` is removed from the world, all its dependants are removed as well.
    ///
    /// - Precondition: `dependant` and `master` must exist as world entities.
    ///
    public func setDependency(of dependant: RuntimeID, on master: RuntimeID) {
        precondition(entities.contains(dependant))
        precondition(entities.contains(master))
        dependencies[master, default: Set()].insert(dependant)
    }
    
    // MARK: - Components
    /// Get a component for a runtime object
    ///
    /// - Parameters:
    ///   - runtimeID: Runtime ID of an object or an ephemeral entity.
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>(for runtimeID: RuntimeID) -> T? {
        components[runtimeID]?[T.self]
    }

    /// Get a component for a runtime object
    ///
    /// - Parameters:
    ///   - objectID: The object ID
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>(for objectID: ObjectID) -> T? {
        guard let runtimeID = objectToEntityMap[objectID] else { return nil }
        return components[runtimeID]?[T.self]
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
    public func setComponent<T: Component>(_ component: T, for runtimeID: RuntimeID) {
        precondition(entities.contains(runtimeID))
        // TODO: Check whether the object exists
        components[runtimeID, default: ComponentSet()].set(component)
    }
    
    /// Set singleton component – a component without an entity.
    ///
    public func setSingleton<T: Component>(_ component: T) {
        // TODO: Check whether the object exists
        singletons.set(component)
    }

    public func removeSingleton<T: Component>(_ component: T.Type) {
        // TODO: Check whether the object exists
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

    /// Set a component for an entity representing an object.
    ///
    /// This is a convenience method.
    ///
    /// - SeeAlso: ``setComponent(_:for:)-(_,RuntimeID)``
    /// - Precondition: Entity representing the object must exist.
    ///
    public func setComponent<T: Component>(_ component: T, for objectID: ObjectID) {
        guard let runtimeID = objectToEntityMap[objectID] else {
            preconditionFailure("Object without entity")
        }
        setComponent(component, for: runtimeID)
    }

    /// Check if an object has a specific component type
    ///
    /// - Parameters:
    ///   - type: The component type to check
    ///   - runtimeID: The object ID
    /// - Returns: True if the object has the component, otherwise false
    ///
    public func hasComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) -> Bool {
        components[runtimeID]?.has(type) ?? false
    }

    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - runtimeID: The object ID
    ///
    public func removeComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeID) {
        // TODO: Check whether the object exists
        components[runtimeID]?.remove(type)
    }
    public func removeComponent<T: Component>(_ type: T.Type, for objectID: ObjectID) {
        guard let runtimeID = objectToEntityMap[objectID] else { return }
        removeComponent(type, for: runtimeID)
    }
    
    public func removeComponentForAll<T: Component>(_ type: T.Type) {
        for id in components.keys {
            components[id]?.remove(type)
        }
    }

    // MARK: - Filter
    
    /// Get a list of objects with given component.
    ///
    public func query<T: Component>(_ componentType: T.Type) -> QueryResult<T> {
        let result: [(RuntimeID, T)] = components.compactMap { id, components in
            guard let comp: T = components[T.self] else {
                return nil
            }
            return (id, comp)
        }
        return QueryResult(result)
    }
    
    // MARK: - Issues

    /// Flag indicating whether any issues were collected
    public var hasIssues: Bool { !issues.isEmpty }

    public func objectHasIssues(_ objectID: ObjectID) -> Bool {
        guard let issues = self.issues[objectID] else { return false }
        return issues.isEmpty
    }

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
    public func appendIssue(_ issue: Issue, for objectID: ObjectID) {
        issues[objectID, default: []].append(issue)
    }
}
