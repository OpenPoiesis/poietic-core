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
public enum SystemDependency {
    /// This system must run before the specified system
    case before(any System.Type)

    /// This system must run after the specified system
    case after(any System.Type)
}

/// A system that processes a runtime frame and populates components.
///
/// Systems are the computational units in the ECS architecture. They read
/// from frame attributes and existing components, then write new components.
///
/// Systems declare their dependencies through component types they produce
/// and require, allowing the system registry to compute execution order
/// automatically.
///
/// ## Example
///
/// ```swift
/// struct ExpressionParserSystem: System {
///     static let dependencies: [SystemDependency] = []
///
///     func update(_ frame: RuntimeFrame) {
///         for object in frame.filter(trait: .Formula) {
///             guard let formula = object["formula"]?.stringValue() else {
///                 continue
///             }
///
///             let expr = try parseExpression(formula)
///             frame.setComponent(UnboundExpression(expression: expr),
///                               for: object.objectID)
///         }
///     }
/// }
/// ```
///
/// - Note: The concept of Systems in this library is for modelling and separation of concerns,
///         not for performance reasons.
///
public protocol System {
    /// Execution order dependencies relative to other systems.
    ///
    /// Use `.before(OtherSystem.self)` or `.after(OtherSystem.self)` to
    /// specify ordering constraints.
    ///
    static var dependencies: [SystemDependency] { get }

    /// Execute the system that reads and updates a runtime frame.
    ///
    /// Systems can:
    /// - Create and add new components using ``RuntimeFrame/setComponent(_:for:)``
    /// - Append user-facing issues using ``RuntimeFrame/appendIssue(_:for:)``
    ///
    /// - Parameter frame: The runtime frame to process
    ///
    func update(_ frame: RuntimeFrame) throws (InternalSystemError)
}

extension System {
    /// Default to no dependencies
    public static var dependencies: [SystemDependency] { [] }
}

/// Error thrown by systems that has not been caused by the user, but that is recoverable in
/// runtime context.
///
/// When receiving this error, an application should provide a visual notification to the user,
/// however should continue functioning.
///
/// Preferably, it might be suggested to the user that developers are to be contacted with this
/// error.
///
public struct InternalSystemError: Error, Equatable {
    public enum Context: Sendable, Equatable {
        case none
        case frame
        case frameComponent(String)

        case object(ObjectID)
        case component(ObjectID, String)
        case attribute(ObjectID, String)
        
        public init(frameComponent: some Component) {
            let typeName = String(describing: type(of: frameComponent))
            self = .frameComponent(typeName)
        }
        public init(id: ObjectID, component: some Component) {
            let typeName = String(describing: type(of: component))
            self = .component(id, typeName)
        }

    }

    public let system: String
    public let message: String
    public let context: Context
    
    public init(_ system: String, message: String, context: Context = .none) {
        self.system = system
        self.message = message
        self.context = context
    }

    public init(_ system: some System, message: String, context: Context = .none) {
        let typeName = String(describing: type(of: system))
        self.system = typeName
        self.message = message
        self.context = context
    }
}
