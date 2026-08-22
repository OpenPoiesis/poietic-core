//
//  System.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2024.
//

/// Dependency specification for system execution order.
///
/// Systems can specify execution order constraints relative to other systems.
///
public enum SystemDependency: Sendable {
    /// This system must run after the specified system and the other system must exist in the
    /// system group.
    case requires(any System.Type)
    
    /// This system must run before the specified system, if the other system is present
    /// in a system group.
    case before(any System.Type)

    /// This system must run after the specified system, if the other system is present
    /// in a system group.
    case after(any System.Type)
}

/// System is a unit of computation that reads and writes a ``World``.
///
/// Systems are the computational units in the ECS architecture. They read
/// from plane attributes and existing components, then write new components.
///
/// Systems declare their dependencies via ``System/dependencies`` so that a ``Schedule``
/// can compute the run order automatically.
///
/// - Note: Systems in this library exist modelling and separation of concerns,
///         not for performance reasons.
///
/// - Note: System is a type rather than just a function, so that it can carry its own metadata:
///   name (used for registration and error reporting) and execution order dependencies.
///
public protocol System: Sendable {
    /// Execution order dependencies relative to other systems.
    ///
    /// Use `.before(OtherSystem.self)` or `.after(OtherSystem.self)` to
    /// specify ordering constraints.
    ///
    static var dependencies: [SystemDependency] { get }
    
    /// Run the system that reads and updates a world.
    ///
    /// Systems can:
    /// - Create and add new components using ``RuntimeEntity/setComponent(_:)`` and ``World/setSingleton(_:)``.
    /// - Append user-facing issues using ``RuntimeEntity/appendIssue(_:)``
    ///
    /// - Parameters:
    ///     - world: The runtime world the system can read and modify.
    ///
    static func update(_ world: World) throws (InternalSystemError)
}

extension System {
    /// Default to no dependencies
    public static var dependencies: [SystemDependency] { [] }
}

/// Marker for transient singletons that are needed between systems, usually within a single
/// schedule.
///
/// Intermediate singletons have no meaning outside of a schedule. They might be preserved for
/// debugging purposes.
///
public protocol IntermediateSingleton: Component { /* Empty */ }



/// Error thrown by systems that has not been caused by the user, but that is recoverable in
/// runtime context.
///
/// When receiving this error, an application should provide a visual notification to the user,
/// however should continue functioning.
///
/// Preferably, it might be suggested to the user that developers are to be contacted with this
/// error.
///
public struct InternalSystemError: Error, Equatable, CustomStringConvertible {
    public enum Context: Sendable, Equatable, CustomStringConvertible {
        case none
        case singleton(String)

        case entity(RuntimeID)
        case object(ObjectID)
        case component(ObjectID, String)
        case attribute(ObjectID, String)
        
        public var description: String {
            switch self {
            case .none: "no context"
            case let .entity(id): "entity \(id)"
            case let .object(id): "object \(id)"
            case let .attribute(id, name): "attribute '\(name)' in object \(id)"
            case let .component(id, name): "component \(name) in object \(id)"
            case let .singleton(name): "singleton component \(name)"
            }
        }
        
        public init(singleton: some Component) {
            let typeName = String(describing: type(of: singleton))
            self = .singleton(typeName)
        }
        public init(id: ObjectID, component: some Component) {
            let typeName = String(describing: type(of: component))
            self = .component(id, typeName)
        }

    }

    public let system: String
    public let message: String
    public let context: Context
    
    public var description: String {
        "Internal System Error (\(system)): \(message). Context: \(context)"
    }
    public init(_ system: String, message: String, context: Context = .none) {
        self.system = system
        self.message = message
        self.context = context
    }

    public init(_ system: System.Type, message: String, context: Context = .none) {
        let typeName = String(describing: system)
        self.system = typeName
        self.message = message
        self.context = context
    }
}
