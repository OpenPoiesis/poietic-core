//
//  AugmentedFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2024.
//

/// Augmented frame is a frame wrapper that adds derived, aggregate or other temporary information
/// to the design frame in form of components.
///
/// Runtime enriches a regular frame with derived information and a list of issues. The derived
/// information is stored in form of components, which are typically created by systems.
/// (see ``System``). Example of a component might be visual representation of a node, or
/// "inflows-outflows" of a node based on surrounding edges.
///
/// Information in the augmented frame is not persisted with the design.
///
/// ## Usage
///
/// ```swift
/// let frame: DesignFrame    // Assuming this is given
/// let augmented = AugmentedFrame(validatedFrame)
///
/// // Use as a regular frame
/// let stocks = augmented.filter(type: .Stock)
///
/// // Access components
/// let expr = augmented.component(UnboundExpression.self, for: objectID)
///
/// // Set components (typically done by systems)
/// augmented.setComponent(expr, for: objectID)
/// ```
///
public final class AugmentedFrame: Frame {
    /// The validated frame which the runtime context is associated with.
    public let wrapped: DesignFrame

    /// Components of particular objects.
    ///
    private var components: [RuntimeEntityID: ComponentSet]

    // TODO: Make a special error protocol confirming to custom str convertible and having property 'hint:String'
    /// User-facing issues collected during frame processing.
    ///
    /// These are non-fatal issues that indicate problems with user data,
    /// not programming errors. The issues are intended to be displayed to the user, preferably
    /// within a context of the object which the issue is associated with.
    ///
    /// Issue list is analogous to a list of syntax errors that were encountered during a
    /// programming language source code compilation.
    ///
    public private(set) var issues: [ObjectID: [Issue]]

    /// Create a runtime frame wrapping a validated frame.
    ///
    /// - Parameter validated: The validated frame to wrap
    ///
    public init(_ validated: DesignFrame) {
        self.wrapped = validated
        self.components = [:]
        self.issues = [:]
    }

    // MARK: - Frame Protocol
    // Delegate all to wrapped validated frame.

    @inlinable public var design: Design { wrapped.design }
    @inlinable public var id: FrameID { wrapped.id }
    @inlinable public var snapshots: [ObjectSnapshot] { wrapped.snapshots }
    @inlinable public var objectIDs: [ObjectID] { wrapped.objectIDs }

    @inlinable public func contains(_ id: ObjectID) -> Bool {
        wrapped.contains(id)
    }

    @inlinable public func object(_ id: ObjectID) -> ObjectSnapshot? {
        wrapped.object(id)
    }

    @inlinable public var nodeKeys: [ObjectID] { wrapped.nodeKeys }
    @inlinable public var edgeKeys: [ObjectID] { wrapped.edgeKeys }
    @inlinable public var edges: [EdgeObject] { wrapped.edges }

    @inlinable public func outgoing(_ origin: NodeKey) -> [Edge] {
        wrapped.outgoing(origin)
    }

    @inlinable public func incoming(_ target: NodeKey) -> [Edge] {
        wrapped.incoming(target)
    }

    // MARK: - Object Components

    /// Get a component for a runtime object
    ///
    /// - Parameters:
    ///   - runtimeID: Runtime ID of an object or an ephemeral entity.
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>(for runtimeID: RuntimeEntityID) -> T? {
        components[runtimeID]?[T.self]
    }

    /// Get a component for a runtime object
    ///
    /// - Parameters:
    ///   - objectID: The object ID
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>(for objectID: ObjectID) -> T? {
        components[.object(objectID)]?[T.self]
    }

    /// Set a component for a specific object
    ///
    /// If a component of the same type already exists for this object,
    /// it will be replaced.
    ///
    /// - Parameters:
    ///   - component: The component to set
    ///   - objectID: The object ID
    ///
    public func setComponent<T: Component>(_ component: T, for runtimeID: RuntimeEntityID) {
        // TODO: Check whether the object exists
        components[runtimeID, default: ComponentSet()].set(component)
    }
    public func setComponent<T: Component>(_ component: T, for objectID: ObjectID) {
        setComponent(component, for: .object(objectID))
    }

    /// Check if an object has a specific component type
    ///
    /// - Parameters:
    ///   - type: The component type to check
    ///   - objectID: The object ID
    /// - Returns: True if the object has the component, otherwise false
    ///
    public func hasComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeEntityID) -> Bool {
        components[runtimeID]?.has(type) ?? false
    }

    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - objectID: The object ID
    ///
    public func removeComponent<T: Component>(_ type: T.Type, for runtimeID: RuntimeEntityID) {
        // TODO: Check whether the object exists
        components[runtimeID]?.remove(type)
    }
    public func removeComponent<T: Component>(_ type: T.Type, for objectID: ObjectID) {
        removeComponent(type, for: .object(objectID))
    }

    /// Get all object IDs that have a specific component type
    ///
    /// - Parameter type: The component type to query
    /// - Returns: Array of object IDs that have this component
    ///
    public func objectIDs<T: Component>(with type: T.Type) -> [ObjectID] {
        components.compactMap { runtimeID, components in
            switch runtimeID {
            case .object(let objectID):
                components.has(type) ? objectID : nil
            case .ephemeral(_):
                nil
            }
        }
    }
    // MARK: - Filter
    
    /// Get a list of objects with given component.
    ///
    public func filter<T: Component>(_ componentType: T.Type) -> some Collection<(ObjectID, T)> {
        components.compactMap { runtimeID, components in
            switch runtimeID {
            case .object(let objectID):
                guard let comp: T = components[T.self] else {
                    return nil
                }
                return (objectID, comp)
            case .ephemeral(_):
                return nil
            }
        }
    }
    // TODO: Is this a good name?
    public func runtimeFilter<T: Component>(_ componentType: T.Type) -> some Collection<(RuntimeEntityID, T)> {
        components.compactMap { runtimeID, components in
            guard let comp: T = components[T.self] else {
                return nil
            }
            return (runtimeID, comp)
        }
    }
    // MARK: - Issues

    /// Flag indicating whether any issues were collected
    public var hasIssues: Bool { !issues.isEmpty }

    public func objectHasIssues(_ objectID: ObjectID) -> Bool {
        guard let issues = self.issues[objectID] else { return false }
        return issues.isEmpty
    }

    public func objectIssues(_ objectID: ObjectID) -> [Issue]? {
        guard let issues = self.issues[objectID], !issues.isEmpty else { return nil }
        return issues
        
    }
    
    /// Append a user-facing issue for a specific object
    ///
    /// Issues are non-fatal problems with user data. Systems should append
    /// issues here rather than throwing errors, allowing processing to continue
    /// and collect multiple issues.
    ///
    /// - Parameters:
    ///   - issue: The error/issue to append
    ///   - objectID: The object ID associated with the issue
    ///
    public func appendIssue(_ issue: Issue, for objectID: ObjectID) {
        issues[objectID, default: []].append(issue)
    }
}

// Testing convenience methods
extension AugmentedFrame {
    func objectHasError<T:IssueProtocol>(_ objectID: ObjectID, error: T) -> Bool {
        guard let issues = objectIssues(objectID) else { return false }

        for issue in issues {
            if let objectError = issue.error as? T, objectError == error {
                return true
            }
        }
        return false
    }
}
