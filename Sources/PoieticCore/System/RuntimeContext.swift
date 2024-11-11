//
//  RuntimeContext.swift
//
//
//  Created by Stefan Urbanek on 20/09/2023.
//

// TODO: Reconsider necessity of this left-over class.
/// Context containing runtime information about the design.
///
/// Runtime context collects issues and components during frame processing.
///
public class RuntimeContext {
    // TODO: We have this in frame
    /// Frame that is being transformed.
    public let frame: any Frame


    var metamodel: Metamodel { frame.design.metamodel }
    

    public var issues: [ObjectID: [Error]]

    /// Runtime components.
    ///
    /// - SeeAlso: ``setComponent(_:for:)``, ``component(for:)``
    ///
    public private(set) var objectComponents: [ObjectID: ComponentSet]

    // Components for the whole context
    // public var globalComponents: [ComponentSet]

    /// Associate a component with an object within the runtime context.
    ///
    /// Only one instance per type of a component can be associated with an object.
    ///
    public func setComponent<T:Component>(_ component: T, for id: ObjectID) {
        objectComponents[id, default: ComponentSet()].set(component)
    }
    
    /// Get a component of a given type for an object.
    ///
    public func component<T:Component>(for id: ObjectID) -> T? {
        objectComponents[id]?[T.self]
    }
    
    /// Create a new context and bind it to a frame.
    ///
    public init(frame: any Frame) {
        self.frame = frame
        self.issues = [:]
        self.objectComponents = [:]
    }
    
    /// Flag indicating whether there were any issues added to to the context.
    ///
    public var hasIssues: Bool { !issues.isEmpty }
    
    /// Appends an error to the list of errors in the context and in the object.
    ///
    /// An error is appended to the list of errors in the ``IssueListComponent``
    /// of the specified node. If the component is not present in the node
    /// then a new one will be created.
    ///
    public func appendIssue(_ error: Error, for id: ObjectID) {
        issues[id, default: []].append(error)
    }
    
    // TODO: Consider the following merge(...) API:
    // func merge(context:rule:)
    // where rule is a case of ContextMergingRule: replace | preserve
}

/// Protocol for objects that manage runtime data.
///
/// Runtime systems are objects that derive data from design frames,
/// manage runtime components.
///
public protocol RuntimeSystem {
    mutating func update(_ context: RuntimeContext)
}
