//
//  RuntimeFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2024.
//

/// Runtime frame is a frame wrapper that adds runtime information in form of components.
///
/// Runtime enriches a regular frame with derived information and a list of issues. The derived
/// information is stored in form of components, which are typically created by systems.
/// (see ``System``). Example of a component might be visual representation of a node, or
/// "inflows-outflows" of a node based on surrounding edges.
///
/// Information in the runtime frame is not persisted with the design.
///
///
/// ## Usage
///
/// ```swift
/// let validatedFrame = try design.validate(design.currentFrame!)
/// let runtimeFrame = RuntimeFrame(validatedFrame)
///
/// // Use as a regular frame
/// let stocks = runtimeFrame.filter(type: .Stock)
///
/// // Access components
/// let expr = runtimeFrame.component(UnboundExpression.self, for: objectID)
///
/// // Set components (typically done by systems)
/// runtimeFrame.setComponent(expr, for: objectID)
/// ```
///
public final class RuntimeFrame: Frame {
    // TODO: We can "wrap the unwrapped" here, we trust the validated frame, so we can refer directly to design frame and remove one level of indirection.
    /// The validated frame which the runtime context is associated with.
    public let wrapped: ValidatedFrame

    /// Components of particular objects.
    ///
    private var objectComponents: [ObjectID: ComponentSet]

    /// Components related to the frame as a whole.
    ///
    private var frameComponents: ComponentSet

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
    public private(set) var issues: [ObjectID: [Error]]

    /// Create a runtime frame wrapping a validated frame.
    ///
    /// - Parameter validated: The validated frame to wrap
    ///
    public init(_ validated: ValidatedFrame) {
        self.wrapped = validated
        self.objectComponents = [:]
        self.frameComponents = ComponentSet()
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

    /// Get a component for a specific object
    ///
    /// - Parameters:
    ///   - objectID: The object ID
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>(for objectID: ObjectID) -> T? {
        objectComponents[objectID]?[T.self]
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
    public func setComponent<T: Component>(_ component: T, for objectID: ObjectID) {
        objectComponents[objectID, default: ComponentSet()].set(component)
    }

    /// Check if an object has a specific component type
    ///
    /// - Parameters:
    ///   - type: The component type to check
    ///   - objectID: The object ID
    /// - Returns: True if the object has the component, otherwise false
    ///
    public func hasComponent<T: Component>(_ type: T.Type, for objectID: ObjectID) -> Bool {
        objectComponents[objectID]?.has(type) ?? false
    }

    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - objectID: The object ID
    ///
    public func removeComponent<T: Component>(_ type: T.Type, for objectID: ObjectID) {
        objectComponents[objectID]?.remove(type)
    }

    /// Get all object IDs that have a specific component type
    ///
    /// - Parameter type: The component type to query
    /// - Returns: Array of object IDs that have this component
    ///
    public func objectIDs<T: Component>(with type: T.Type) -> [ObjectID] {
        objectComponents.compactMap { objectID, components in
            components.has(type) ? objectID : nil
        }
    }
    // MARK: - Filter
    
    /// Get a list of objects with given component.
    ///
    public func filter<T: Component>(_ componentType: T.Type) -> some Collection<(ObjectID, T)> {
        return self.objectIDs.compactMap { objectID in
            guard let comp: T = self.component(for: objectID) else { return nil }
            return (objectID, comp)
        }
    }

    // MARK: - Frame Components

    /// Get a frame-level metadata component
    ///
    /// Frame-level components store metadata that applies to the entire frame,
    /// such as computation order or dependency graphs.
    ///
    /// - Parameter type: The component type to retrieve
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func frameComponent<T: Component>(_ type: T.Type) -> T? {
        frameComponents[type]
    }

    /// Set a frame-level metadata component
    ///
    /// - Parameter component: The component to set
    ///
    public func setFrameComponent<T: Component>(_ component: T) {
        frameComponents.set(component)
    }

    /// Check if a frame-level component exists
    ///
    /// - Parameter type: The component type to check
    /// - Returns: True if the component exists, otherwise false
    ///
    public func hasFrameComponent<T: Component>(_ type: T.Type) -> Bool {
        frameComponents.has(type)
    }

    /// Remove a frame-level component
    ///
    /// - Parameter type: The component type to remove
    ///
    public func removeFrameComponent<T: Component>(_ type: T.Type) {
        frameComponents.remove(type)
    }

    // MARK: - Issues

    /// Flag indicating whether any issues were collected
    public var hasIssues: Bool { !issues.isEmpty }

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
    public func appendIssue(_ issue: Error, for objectID: ObjectID) {
        issues[objectID, default: []].append(issue)
    }
}
