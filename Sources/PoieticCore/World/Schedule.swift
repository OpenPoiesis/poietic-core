//
//  Schedule.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 21/12/2025.
//

/// Tag protocol for system schedule labels.
///
/// Schedule labels are compile-time tags of system schedules.
///
/// - SeeAlso: ``PlaneChangeSchedule``, ``InteractivePreviewSchedule``.
///
public protocol ScheduleLabel {
    // Empty protocol, just a tag
}

/// Schedule label for systems that are run when plane did change.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum PlaneChangeSchedule: ScheduleLabel {}

/// Schedule label for systems that are run during interactive session, for example
/// a dragging or an object placement session.
///
/// For example, while dragging session, the systems are run on each move event.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum InteractivePreviewSchedule: ScheduleLabel {}

/// Schedule label for systems that run a simulation.
///
/// The schedule is typically run after ``PlaneChangeSchedule``.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum SimulationSchedule: ScheduleLabel {}

/// System schedule is a collection of systems that run in order of their dependency.
///
/// ## Use
///
/// Typically there is one group per problem domain and even per application. For example,
/// a Stock and Flow simulation application would have just one system scheduler with systems
/// for expression parsing, flow dependency graph and computational model creation.
///
/// ## Example
///
/// ```swift
/// let plane: DesignPlane // Assume we have this.
/// let schedule = Schedule()
///
/// schedule.add(ExpressionParserSystem.self)
/// schedule.add(ParametereDependecySystem.self)
/// schedule.add(StockFlowAnalysisSystem.self)
///
/// let world = World(plane: plane)
/// world.set
/// try world.run(schedule)
/// ```
///
/// - Note: The concept of Systems in this library is for modelling and separation of concerns,
///         not for performance reasons.
///
public final class Schedule {
    public let label: ScheduleLabel.Type
    // TODO: Make immutable through public interface
    /// Registered systems indexed by type name
    private var systems: [ObjectIdentifier: System.Type]

    private var explicitEdges: [(origin: ObjectIdentifier, target: ObjectIdentifier)] = []

    /// Computed execution order
    private var _executionOrder: [System.Type]
    private var _instances: [any System]
    

    convenience public init(label: ScheduleLabel.Type, systems: System.Type ...) {
        self.init(label: label, systems: systems)
    }

    /// Create a new schedule.
    ///
    /// - Parameters:
    ///     - label: Schedule label.
    ///     - systems: List of systems in the schedule.
    ///     - order: Explicit order of system execution, in addition to the intrinsic order
    ///         defined by ``System/dependencies``.
    ///
    /// - Precondition: The systems in the `order` list must exist in the `systems` list.
    /// - Precondition: The system order must not form a loop.
    ///
    public init(label: ScheduleLabel.Type, systems: [System.Type], order: [(System.Type, before: System.Type)] = []) {
        self.systems = [:]
        self._executionOrder = []
        self._instances = []
        self.label = label
        self.explicitEdges = order.map { (ObjectIdentifier($0.0), ObjectIdentifier($0.1)) }
        self.add(systems)
    }

    /// Register a system
    ///
    /// After registration, execution order is recomputed based on all
    /// registered systems and their dependencies.
    ///
    /// There can be only one system of given type. When registering a system of already registered
    /// system type, the old one will be discarded and the new one will be used.
    ///
    /// - Parameter system: The system to register
    /// - Precondition: The system dependencies must not contain a cycle and references must exist.
    ///
    public func add(_ system: System.Type) {
        let id = ObjectIdentifier(system)

        systems[id] = system
        _updateDependencyOrder()
    }

    /// Register multiple systems at once.
    ///
    /// - SeeAlso: ``add(_:)``
    ///
    public func add(_ systems: [System.Type]) {
        for system in systems {
            let id = ObjectIdentifier(system)
            self.systems[id] = system
        }
        _updateDependencyOrder()
    }
    
    /// Define execution order of two systems, in addition to the intrinsic execution order defined
    /// by the systems through ``System/dependencies``.
    ///
    /// The system `system` will be run before the `other`.
    ///
    /// The new order must not create a loop.
    ///
    /// - Precondition: Both systems must be present in the schedule.
    ///
    /// - SeeAlso: ``add(_:)``.
    ///
    public func order(_ system: System.Type, before other: System.Type) {
        precondition(self.systems[ObjectIdentifier(system)] != nil)
        precondition(self.systems[ObjectIdentifier(other)] != nil)
        explicitEdges.append((ObjectIdentifier(system),ObjectIdentifier(other)))
        _updateDependencyOrder()
    }

    /// Define execution order of two systems, in addition to the intrinsic execution order defined
    /// by the systems through ``System/dependencies``.
    ///
    /// The system `system` will be run after the `other`.
    ///
    /// The new order must not create a loop.
    ///
    /// - Precondition: Both systems must be present in the schedule.
    ///
    /// - SeeAlso: ``add(_:)``.
    ///
    public func order(_ system: System.Type, after other: System.Type) {
        precondition(self.systems[ObjectIdentifier(system)] != nil)
        precondition(self.systems[ObjectIdentifier(other)] != nil)
        explicitEdges.append((ObjectIdentifier(other),ObjectIdentifier(system)))
        _updateDependencyOrder()
    }

    /// Creates instances of the systems and initialises them with the world.
    ///
    public func initialize(with world: World) throws (InternalSystemError) {
        // TODO: Add plane or some initialisation context
        for systemType in _executionOrder {
            let system = systemType.init(world)
            _instances.append(system)
        }
    }
    
    /// Run all systems in dependency order
    ///
    /// Systems are run sequentially in topological order based on
    /// their declared dependencies.
    ///
    /// If the systems were not yet initialised they will be initialised with ``initialize(with:)``
    /// before running the ``System/update(_:)``method.
    ///
    /// - Parameters:
    ///     - world: World to run the systems with.
    ///
    /// - Throws: Errors from system execution
    ///
    public func update(_ world: World) throws (InternalSystemError) {
        if _instances.isEmpty {
            try self.initialize(with: world)
        }
        for system in _instances {
            try system.update(world)
        }
    }

    /// Get names of the systems in the the computed execution order
    ///
    public func debugDependencyOrder() -> [String] {
        _executionOrder.map { String(describing: $0) }
    }

    /// Compute execution order based on system dependencies
    ///
    /// Uses topological sort to order systems respecting `.before()` and
    /// `.after()` constraints.
    ///
    /// - Parameters:
    ///     - systems: List of systems to be ordered.
    ///
    /// - Returns: Sorted array of systems.
    /// - Precondition: There must be no dependency cycle within systems.
    /// - Precondition: If `strict` is `true` then all systems listed in dependencies must be
    ///   present in the list. If `strict` is `false` then systems not present are ignored.
    ///
    internal func _updateDependencyOrder() {
        var edges: [(origin: ObjectIdentifier, target: ObjectIdentifier)] = self.explicitEdges

        var systemMap: [ObjectIdentifier: System.Type] = [:]
        for system in self.systems.values {
            systemMap[ObjectIdentifier(system)] = system
        }
        var maybeIndependent: Set<ObjectIdentifier> = []
        
        // First pass: validate hard dependencies and collect soft ones
        for system in self.systems.values {
            let systemID = ObjectIdentifier(system)
            guard !system.dependencies.isEmpty else {
                maybeIndependent.insert(systemID)
                continue
            }
            
            for dependency in system.dependencies {
                let origin: ObjectIdentifier
                let target: ObjectIdentifier
                let otherID: ObjectIdentifier
                let required: Bool
                switch dependency {
                case let .requires(id):
                    otherID = ObjectIdentifier(id)
                    (origin, target) = (systemID, otherID)
                    required = true
                case let .before(id):
                    otherID = ObjectIdentifier(id)
                    (origin, target) = (systemID, otherID)
                    required = false
                case let .after(id):
                    otherID = ObjectIdentifier(id)
                    (origin, target) = (otherID, systemID)
                    required = false
                }
                
                guard systemMap[otherID] != nil else {
                    if required {
                        fatalError("System \(system) requires missing system: \(otherID)")
                    }
                    else {
                        maybeIndependent.insert(systemID)
                    }
                    continue
                }
                
                edges.append((origin: origin, target: target))
            }
        }
        
        guard let sorted = topologicalSort(edges) else {
            fatalError("Circular dependency detected in systems")
        }

        let independent = maybeIndependent.filter { !sorted.contains($0) }
        let all = independent + sorted
        self._executionOrder = all.compactMap { systemMap[$0] }
    }
}
