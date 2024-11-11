//
//  ErrorComponent.swift
//
//
//  Created by Stefan Urbanek on 20/09/2023.
//

/// Component that holds a list of errors related to a node.
///
/// This is a run-time component, its content will not be persisted.
///
public struct IssueListComponent: Component {
    public var errors: [Error] = []
    // public var warnings: [???] = []
    
    public init(errors: [Error]) {
        self.errors = errors
    }
    mutating public func append(_ error: Error) {
        self.errors.append(error)
    }
    
    mutating public func removeAll() {
        self.errors.removeAll()
    }
}

//extension ObjectSnapshot {
//    /// An error is appended to the list of errors in the ``IssueListComponent``
//    /// of the specified node. If the component is not present in the node
//    /// then a new one will be created.
//    ///
//    public func appendIssue(_ error: Error) {
//        if components.has(IssueListComponent.self) {
//            components[IssueListComponent.self]!.append(error)
//        }
//        else {
//            let component = IssueListComponent(errors: [error])
//            components.set(component)
//        }
//    }
//    /// Remove all issues from the issue list component.
//    ///
//    /// If the object has no ``IssueListComponent`` then nothing happens.
//    ///
//    /// - SeeAlso: ``IssueListComponent``.
//    public func removeAllIssues() {
//        if components.has(IssueListComponent.self) {
//            components[IssueListComponent.self]!.removeAll()
//        }
//    }
//    
//    /// Returns a list of object issues.
//    ///
//    /// The issues are extracted from the ``IssueListComponent``. If the object
//    /// has no ``IssueListComponent``, then an empty list is returned.
//    ///
//    public var issues: [Error] {
//        if let component: IssueListComponent = components[IssueListComponent.self] {
//            return component.errors
//        }
//        else {
//            return []
//        }
//    }
//
//    /// Flag whether the node has any associated issues.
//    ///
//    /// If the node has ``IssueListComponent`` then the flag is `true` if the
//    /// component contains any issues, otherwise `false`.
//    ///
//    /// If the node does not have a ``IssueListComponent`` then the flag is
//    /// `false`.
//    ///
//    public var hasIssues: Bool {
//        if let component: IssueListComponent = components[IssueListComponent.self] {
//            return !component.errors.isEmpty
//        }
//        else {
//            return false
//        }
//    }
//}
