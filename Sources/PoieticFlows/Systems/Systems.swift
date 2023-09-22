//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 20/09/2023.
//

import PoieticCore

public struct TransformationContext {
    let frame: MutableFrame
    var errors: [ObjectID: [Error]] = [:]
    
    /// Appends an error to the list of errors in the context and in the object.
    ///
    /// An error is appended to the list of errors in the ``IssueListComponent``
    /// of the specified node. If the component is not present in the node
    /// then a new one will be created.
    /// 
    public mutating func appendError(_ error: Error, for id: ObjectID) {
        errors[id, default: []].append(error)
        frame.object(id).appendIssue(error)
    }
}

/// Protocol for systems that transform frame data into another kind
/// of data within the same frame.
///
/// Assumption: We are all adults. This type of system is expected not to mutate
/// existing components that are not created by the system itself.
///
public protocol TransformationSystem {
    mutating func update(_ context: inout TransformationContext)
}
