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
    func update(_ frame: RuntimeFrame)
}

extension System {
    /// Default to no dependencies
    public static var dependencies: [SystemDependency] { [] }
}
