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
    /// Registered systems indexed by type name
    private var systems: [ObjectIdentifier: System.Type]

    /// Computed execution order
    private var _executionOrder: [System.Type]
    private var _instances: [any System]
    

    convenience public init(_ systems: System.Type ...) {
        self.init(systems)
    }

    public init(_ systems: [System.Type], strict: Bool = true) {
        self.systems = [:]
        self._executionOrder = []
        self._instances = []
        self.register(systems, strict: strict)
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
        let id = system._systemTypeIdentifier

        systems[id] = system
        _executionOrder = Self.dependencyOrder(Array(systems.values))
    }

    /// Register multiple systems at once.
    ///
    /// - SeeAlso: ``register()``
    ///
    public func register(_ systems: [System.Type], strict: Bool = true) {
        for system in systems {
            let id = system._systemTypeIdentifier
            self.systems[id] = system
        }
        _executionOrder = Self.dependencyOrder(Array(self.systems.values), strict: strict)
    }


    /// Execute all systems in dependency order
    ///
    /// Systems are executed sequentially in topological order based on
    /// their declared dependencies.
    ///
    /// - Parameter frame: The runtime frame to process
    /// - Throws: Errors from system execution
    ///
    public func update(_ frame: AugmentedFrame) throws (InternalSystemError) {
        if _instances.isEmpty {
            self.instantiate()
        }
        for system in _instances {
            try system.update(frame)
        }
    }

    internal func instantiate() {
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
    public static func dependencyOrder(_ systems: [System.Type], strict: Bool = true) -> [System.Type]
    {
        var systemMap: [ObjectIdentifier: System.Type] = [:]
        var edges: [(ObjectIdentifier, ObjectIdentifier)] = []

        for system in systems {
            let id = system._systemTypeIdentifier
            systemMap[id] = system
        }
        for system in systemMap.values {
            let systemID = system._systemTypeIdentifier
            for dep in system.dependencies {
                switch dep {
                case .before(let other):
                    let otherID = other._systemTypeIdentifier
                    guard systemMap[otherID] != nil else {
                        assert(!strict, "Error sorting system \(system): Missing system: \(other)")
                        continue
                    }
                    edges.append((origin: systemID, target: otherID))
                case .after(let other):
                    let otherID = other._systemTypeIdentifier
                    guard systemMap[otherID] != nil else {
                        assert(!strict, "Error sorting system \(system): Missing system: \(other)")
                        continue
                    }
                    edges.append((origin: otherID, target: systemID))
                }
            }
        }
        guard let sorted = topologicalSort(edges) else {
            fatalError("Circular dependency in Systems")
        }
        
        var independent: [ObjectIdentifier] = []
        for system in systems where system.dependencies.count == 0 {
            let id = ObjectIdentifier(system)
            guard !independent.contains(id) && !sorted.contains(id) else { continue }
            independent.append(id)
        }
        let result = (independent + sorted).compactMap { systemMap[$0] }

        return result
    }
}

extension System {
    internal static var _systemTypeIdentifier: ObjectIdentifier {
        return ObjectIdentifier(self)
    }
}
