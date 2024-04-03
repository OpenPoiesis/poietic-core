//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 20/09/2023.
//

public class TransformationContext {
    // TODO: Alternative names: UpdateContext, MutationContext
    public let metamodel: Metamodel
    /// Frame that is being transformed.
    public let frame: MutableFrame
    
    // TODO: Private
    public var issues: [ObjectID: [Error]]
    
//    public var objectsWithIssues: [ObjectID] {
//        return Array(issues.keys)
//    }
//    
//    public func issuesForObject(_ id: ObjectID) -> [Error] {
//        issues[id] ?? []
//    }
    
    public init(frame: MutableFrame) {
        self.metamodel = frame.design.metamodel
        self.frame = frame
        self.issues = [:]
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
        frame.object(id).appendIssue(error)
    }
}

/// Protocol for objects that makes changes to a frame.
///
/// Frame transformers are objects that update a frame by changing objects
/// components, adding components, adding and removing objects. Frame
/// transformers change, add or remove only specific set of components
/// and object types.
///
/// - Note: Currently there is no way to specify and constraint transformers
///   to specific object and component types. We rely on gentleman's promise
///   of the transformer's developer not to touch other types as documented
///   for the specific transformer.
///
public protocol FrameTransformer {
    // TODO: Rename to FrameTransform
    // TODO: Rename to "apply"
    mutating func update(_ context: TransformationContext)
}
