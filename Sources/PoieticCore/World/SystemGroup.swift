//
//  SystemGroup.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2024.
//

/*
 Development Notes:
 
 - This is an early sketch of Systems and SystemGroups
 - TODO: Have a central per-app or per-design system registry
 - TODO: ^^ see poietic-godot and DesignController and RuntimePhase for seed of the above TODO
 - TODO: Remove mutability of System-group
 */

/// System group is a collection of systems that run in order of their dependency.
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
/// let systems = SystemGroup()
///
/// systems.register(ExpressionParserSystem())
/// systems.register(ParametereDependecySystem())
/// systems.register(StockFlowAnalysisSystem())
///
/// let runtimeFrame = RuntimeFrame(validatedFrame)
/// try systems.update(runtimeFrame)
/// ```
///
/// - Note: The concept of Systems in this library is for modelling and separation of concerns,
///         not for performance reasons.
///
public final class SystemGroup {
    // TODO: Make immutable through public interface
    /// Registered systems indexed by type name
    private var systems: [ObjectIdentifier: System.Type]

    /// Computed execution order
    private var _executionOrder: [System.Type]
    private var _instances: [any System]
    

    convenience public init(_ systems: System.Type ...) {
        self.init(systems)
    }

    public init(_ systems: [System.Type]) {
        self.systems = [:]
        self._executionOrder = []
        self._instances = []
        self.register(systems)
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
    public func register(_ system: System.Type) {
        let id = ObjectIdentifier(system)

        systems[id] = system
        _executionOrder = Self.dependencyOrder(Array(systems.values))
    }

    /// Register multiple systems at once.
    ///
    /// - SeeAlso: ``register()``
    ///
    public func register(_ systems: [System.Type]) {
        for system in systems {
            let id = ObjectIdentifier(system)
            self.systems[id] = system
        }
        _executionOrder = Self.dependencyOrder(Array(self.systems.values))
    }


    /// Run all systems in dependency order
    ///
    /// Systems are run sequentially in topological order based on
    /// their declared dependencies.
    ///
    /// - Parameter frame: The runtime frame to process
    /// - Throws: Errors from system execution
    ///
    public func update(_ world: World) throws (InternalSystemError) {
        if _instances.isEmpty {
            self.instantiate()
        }
        for system in _instances {
            try system.update(world)
        }
    }

    public func instantiate() {
        // TODO: Add frame or some initialisation context
        for systemType in _executionOrder {
            let system = systemType.init()
            _instances.append(system)
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
