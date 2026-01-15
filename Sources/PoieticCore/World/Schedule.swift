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
/// - SeeAlso: ``FrameChange``, ``InteractivePreview``.
///
public protocol ScheduleLabel {
    // Empty protocol, just a tag
}

/// Schedule label for systems that are run when frame did change.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum FrameChangeSchedule: ScheduleLabel {}

/// Schedule label for systems that are run during interactive session, for example
/// a dragging or an object placement session.
///
/// For example, while dragging session, the systems are run on each move event.
///
/// - SeeAlso: ``World/run(schedule:)``
public enum InteractivePreviewSchedule: ScheduleLabel {}

/// Schedule label for systems that run a simulation.
///
/// The schedule is typically run after ``FrameChangeSchedule``.
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
/// let frame: DesignFrame // Assume we have this.
/// let schedule = Schedule()
///
/// schedule.add(ExpressionParserSystem.self)
/// schedule.add(ParametereDependecySystem.self)
/// schedule.add(StockFlowAnalysisSystem.self)
///
/// let world = World(frame: frame)
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

    /// Computed execution order
    private var _executionOrder: [System.Type]
    private var _instances: [any System]
    

    convenience public init(label: ScheduleLabel.Type, systems: System.Type ...) {
        self.init(label: label, systems: systems)
    }

    public init(label: ScheduleLabel.Type, systems: [System.Type]) {
        self.systems = [:]
        self._executionOrder = []
        self._instances = []
        self.label = label
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
        _executionOrder = Self.dependencyOrder(Array(systems.values))
    }

    /// Register multiple systems at once.
    ///
    /// - SeeAlso: ``register()``
    ///
    public func add(_ systems: [System.Type]) {
        for system in systems {
            let id = ObjectIdentifier(system)
            self.systems[id] = system
        }
        _executionOrder = Self.dependencyOrder(Array(self.systems.values))
    }

    /// Creates instances of the systems and initialises them with the world.
    ///
    public func initialize(with world: World) throws (InternalSystemError) {
        // TODO: Add frame or some initialisation context
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
        _executionOrder.map { String(describing: type(of: $0)) }
    }

    /// Compute execution order based on system dependencies
    ///
    /// Uses topological sort to order systems respecting `.before()` and
    /// `.after()` constraints.
    ///
    /// - Parameters:
    ///     - systems: List of systems to be ordered.
    ///     - strict: Flag whether dependencies are strictly required.
    ///
    /// - Returns: Sorted array of systems.
    /// - Precondition: There must be no dependency cycle within systems.
    /// - Precondition: If `strict` is `true` then all systems listed in dependencies must be
    ///   present in the list. If `strict` is `false` then systems not present are ignored.
    ///
    public static func dependencyOrder(_ systems: [System.Type]) -> [System.Type] {
        let systemMap = systems.reduce(into: [ObjectIdentifier: System.Type]()) {
            (result, system) in
            result[ObjectIdentifier(system)] = system
        }
        
        var edges: [(origin: ObjectIdentifier, target: ObjectIdentifier)] = []
        var maybeIndependent: Set<ObjectIdentifier> = []
        
        // First pass: validate hard dependencies and collect soft ones
        for system in systems {
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

        return (independent + sorted).compactMap { systemMap[$0] }
    }
}
