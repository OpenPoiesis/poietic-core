//
//  SystemScheduler.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2024.
//

/*
 Development Notes:
 
 - A system processes all entities that match its component query, and ignores those that don't.
 
 
 */

/// System scheduler is responsible for system registration, dependency ordering and running.
///
/// ## Use
///
/// Typically there is one scheduler per problem domain and even per application. For example,
/// a Stock and Flow simulation application would have just one system scheduler with systems
/// for expression parsing, flow dependency graph and computational model creation.
///
/// ## Example
///
/// ```swift
/// let scheduler = SystemScheduler()
///
/// scheduler.register(ExpressionParserSystem())
/// scheduler.register(ParametereDependecySystem())
/// scheduler.register(StockFlowAnalysisSystem())
///
/// let runtimeFrame = RuntimeFrame(validatedFrame)
/// try scheduler.execute(runtimeFrame)
/// ```
///
/// - Note: The concept of Systems in this library is for modelling and separation of concerns,
///         not for performance reasons.
///
public final class SystemScheduler {
    /// Registered systems indexed by type name
    private var systems: [ObjectIdentifier: any System]

    /// Computed execution order
    private var _executionOrder: [any System]

    public init() {
        self.systems = [:]
        self._executionOrder = []
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
    public func register(_ system: any System) {
        let id = type(of: system)._systemTypeIdentifier

        systems[id] = system
        _executionOrder = Self.dependencyOrder(Array(systems.values))
    }
    
    /// Register multiple systems at once.
    ///
    /// - SeeAlso: ``register()``
    ///
    public func register(_ systems: [any System]) {
        for system in systems {
            let id = type(of: system)._systemTypeIdentifier
            self.systems[id] = system
        }
        _executionOrder = Self.dependencyOrder(Array(self.systems.values))
    }


    /// Execute all systems in dependency order
    ///
    /// Systems are executed sequentially in topological order based on
    /// their declared dependencies.
    ///
    /// - Parameter frame: The runtime frame to process
    /// - Throws: Errors from system execution
    ///
    public func execute(_ frame: RuntimeFrame) throws (InternalSystemError) {
        for system in _executionOrder {
            let typeName = String(describing: type(of: system))
            debugPrint("=== Executing system: \(typeName)")
            try system.update(frame)
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
    /// - Returns: Sorted array of systems
    /// - Precondition: Systems in the dependency references must be known and there must be no
    ///   cycle.
    ///
    public static func dependencyOrder(_ systems: [any System]) -> [any System]
    {
        var systemMap: [ObjectIdentifier: any System] = [:]
        var edges: [(ObjectIdentifier, ObjectIdentifier)] = []

        for system in systems {
            let id = type(of: system)._systemTypeIdentifier
            systemMap[id] = system
        }
        for system in systems {
            let systemID = type(of: system)._systemTypeIdentifier
            for dep in type(of: system).dependencies {
                switch dep {
                case .before(let other):
                    let otherID = other._systemTypeIdentifier
                    precondition(systemMap[otherID] != nil,
                           "Error sorting system \(system): Missing system: \(other)")
                    edges.append((origin: systemID, target: otherID))
                case .after(let other):
                    let otherID = other._systemTypeIdentifier
                    precondition(systemMap[otherID] != nil,
                           "Error sorting system \(system): Missing system: \(other)")
                    edges.append((origin: otherID, target: systemID))
                }
            }
        }

        guard let sorted = topologicalSort(edges) else {
            fatalError("Circular dependency in Systems")
        }
        
        let result = sorted.compactMap { systemMap[$0] }
        
        return result
    }
}

extension System {
    internal static var _systemTypeIdentifier: ObjectIdentifier {
        return ObjectIdentifier(self)
    }
}
