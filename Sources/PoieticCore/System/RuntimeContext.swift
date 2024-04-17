//
//  RuntimeContext.swift
//
//
//  Created by Stefan Urbanek on 20/09/2023.
//

/// Context containing runtime information about the design.
///
public class RuntimeContext {
    // TODO: We have this in frame
    public let metamodel: Metamodel
    
    /// Frame that is being transformed.
    public let frame: Frame
    
    // TODO: Private
    public var issues: [ObjectID: [Error]]

    public var objectComponents: [ObjectID: ComponentSet]
    // Components for the whole context
    // public var globalComponents: [ComponentSet]

    public func setComponent<T:Component>(_ component: T, for id: ObjectID) {
        objectComponents[id, default: ComponentSet()].set(component)
    }
    
    public func component<T:Component>(for id: ObjectID) -> T? {
        objectComponents[id]?[T.self]
    }
    
    //    public var objectsWithIssues: [ObjectID] {
//        return Array(issues.keys)
//    }
//
//    public func issuesForObject(_ id: ObjectID) -> [Error] {
//        issues[id] ?? []
//    }
    
    public init(frame: Frame) {
        self.metamodel = frame.design.metamodel
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
        frame[id].appendIssue(error)
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
