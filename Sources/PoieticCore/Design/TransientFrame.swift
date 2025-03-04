//
//  TransientFrame.swift
//  
//
//  Created by Stefan Urbanek on 23/03/2023.
//

/// Error thrown when validating and accepting a frame.
///
/// - SeeAlso: ``TransientFrame/accept()``
/// 
public enum TransientFrameError: Error {
    /// The frame contains references to objects that are not present in the frame.
    ///
    /// Use ``TransientFrame/brokenReferences()`` to investigate.
    ///
    case brokenEdgeEndpoint
    case brokenChild
    case brokenParent
    case parentChildMismatch
    case parentChildCycle
    case edgeEndpointNotANode
}

/// Transient frame that represents a change transaction.
///
/// Designated way of creating transient frames is with ``Design/createFrame(deriving:id:)``.
/// The frame needs to be accepted to the design to be considered valid and to be used
/// by other parts of the library.
///
/// ```swift
/// let design: Design
///
/// let frame = design.createFrame()
///
/// let note = frame.create(ObjectType.Note)
/// note["text"] = "Important note"
///
/// do {
///     try design.accept(frame)
/// }
/// catch { // Handle error
///     design.discard(frame)
/// }
/// ```
///
/// Multiple changes are applied to a transient frame, which can be then
/// validated and turned into a stable frame using ``Design/accept(_:appendHistory:)``.
/// If the changes can not be validated or for any other reason the changes
/// are not to be accepted, the frame can be discarded by ``Design/discard(_:)``.
///
/// Transient frames are not persisted, they exist only during runtime.
///
/// The changes that can be performed with the transient frame:
///
/// - Mutate existing objects in the frame using
///   ``TransientFrame/mutate(_:)``.
/// - Add objects with ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
///    or ``TransientFrame/insert(_:)``.
/// - Change parent/child hierarchy.
///
/// Once a transient frame is accepted or discarded, it can no longer be modified.
///
public final class TransientFrame: Frame {
    /// Design with which this frame is associated with.
    ///
    public unowned let design: Design
    
    /// ID of the frame.
    ///
    /// The ID is unique within the design.
    ///
    public let id: FrameID
    
    
    /// State of the transient frame.
    ///
    public enum State {
        /// The frame is transient and can be modified.
        case transient
        /// The frame has been accepted and can not be modified any more.
        case accepted
        /// The frame has been discarded and can not be modified any more.
        case discarded
    }
    /// Current state of the transient frame.
    ///
    /// Frame can be modified if it is in ``State/transient``.
    ///
    var state: State = .transient
    
    enum TransientReference {
        case stable(DesignObject)
        case mutable(MutableObject)
        
        public var isMutable: Bool {
            switch self {
            case .stable(_): false
            case .mutable(_): true
            }
        }
        
        var snapshotID: SnapshotID {
            switch self {
            case let .stable(object): object.snapshotID
            case let .mutable(object): object.snapshotID
            }
        }
        
        var parent: ObjectID? {
            switch self {
            case let .stable(object): object.parent
            case let .mutable(object): object.parent
            }
        }
        
        var children: ChildrenSet {
            switch self {
            case let .stable(object): object.children
            case let .mutable(object): object.children
            }
        }
        
        var structure: Structure {
            switch self {
            case let .stable(object): object.structure
            case let .mutable(object): object.structure
            }
        }
        
        var edgeEndpoints: (ObjectID, ObjectID)? {
            switch self {
            case let .stable(object):
                if case let .edge(origin, target) = object.structure {
                    return (origin, target)
                }
                else {
                    return nil
                }
            case let .mutable(object):
                if case let .edge(origin, target) = object.structure {
                    return (origin, target)
                }
                else {
                    return nil
                }
            }
        }
        
        func asStable() -> DesignObject {
            switch self {
            case let .stable(object): object
            case let .mutable(object): DesignObject(body: object._body, components: object.components)
            }
        }
    }
    
    var objects: [ObjectID:TransientReference]
    
    /// Cache of snapshot IDs used to verify unique ownership
    ///
    var snapshotIDs: Set<SnapshotID>
    
    /// List of object IDs that were provided during initialisation.
    ///
    public let originalIDs: Set<ObjectID>
    
    /// A set of original objects that were removed from the frame.
    ///
    /// This is a subset of ``originalIDs``.
    ///
    public internal(set) var removedObjects: Set<ObjectID> = Set()
    
    public var changedObjects: [ObjectID] {
        objects.values.compactMap { ref in
            switch ref {
            case .mutable(let obj): obj.id
            case .stable(_): nil
            }
        }
    }
    
    /// List of snapshots in the frame.
    ///
    /// - Note: The order of the snapshots is arbitrary. Do not rely on it.
    ///
    public var snapshots: [DesignObject] {
        objects.values.map { $0.asStable() }
    }
    
    /// Returns `true` if the frame contains an object with given object ID.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return self.objects[id] != nil
    }
    
    /// Get an object with identity `id`.
    ///
    /// Returns an object in its mutation state as it was a the time of the call. If the requested
    /// object was not mutated at the time of the call, but was mutated later, then returned value
    /// still refers to the original object.
    ///
    /// - Returns: Transient object in a state at the time of the call.
    ///
    /// - Precondition: Frame must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> DesignObject {
        guard let ref = objects[id] else {
            preconditionFailure("Unknown object \(id)")
        }
        return ref.asStable()
    }
    
    /// Get an object version of object with identity `id`.
    ///
    public subscript(id: ObjectID) -> DesignObject {
        get { object(id) }
    }
    
    /// Flag whether the mutable frame has any changes.
    public var hasChanges: Bool {
        (!removedObjects.isEmpty
         || objects.values.contains(where: {$0.isMutable} ) )
    }
    
    /// Create a new mutable frame.
    ///
    /// Creates a new mutable frame that will be associated with the `design`.
    ///
    /// - Parameters:
    ///     - design: The design the frame will be associated with.
    ///     - id: ID of the frame. Must be unique within the design.
    ///     - snapshots: List of snapshots to be associated with the frame.
    ///
    /// The frame will contain all the provided snapshots, but will not own
    /// them. The frame will own only snapshots inserted directly to the frame
    /// using ``insert(_:)`` or by deriving an object using
    /// ``mutate(_:)``.
    ///
    /// Snapshots removed from the mutable frame are only disassociated with the
    /// frame, not removed from the design or any other frame.
    ///
    public init(design: Design,
                id: FrameID,
                snapshots: [DesignObject]? = nil) {
        self.design = design
        self.id = id
        self.objects = [:]
        self.snapshotIDs = Set()
        var originals: Set<ObjectID> = Set()
        
        if let snapshots {
            for snapshot in snapshots {
                self.objects[snapshot.id] = TransientReference.stable(snapshot)
                self.snapshotIDs.insert(snapshot.snapshotID)
                originals.insert(snapshot.id)
            }
        }
        self.originalIDs = originals
    }
    
    /// Create a new object within the frame.
    ///
    /// The method creates a new object and assigns default values as defined
    /// in the type.
    ///
    /// If object ID or snapshot ID are provided, they are used, otherwise
    /// they are generated.
    ///
    /// - Parameters:
    ///     - type: Object type.
    ///     - id: Proposed object ID. If not provided, one will be generated.
    ///     - snapshotID: Proposed snapshot ID. If not provided, one will be generated.
    ///     - children: Children of the new object.
    ///     - attributes: Attribute dictionary to be used for object
    ///       initialisation.
    ///     - parent: Optional parent object in the hierarchy of objects.
    ///     - components: List of components to be set for the newly created object.
    ///     - structure: Structural component of the new object that must match
    ///       the object type.
    ///
    /// - Note: Attributes are not checked according to the object type during
    ///   object creation. The object is not yet required to satisfy any
    ///   constraints.
    /// - Note: Existence of the parent is not verified, it will be during the
    ///   frame insertion.
    ///
    /// - SeeAlso: ``TransientFrame/insert(_:)``
    ///
    /// - Precondition: If `id` or `snapshotID` is provided, it must not exist
    ///   in the frame.
    /// - Precondition: `structure` must match ``ObjectType/structuralType``.
    ///
    @discardableResult
    public func create(_ type: ObjectType,
                       id: ObjectID? = nil,
                       snapshotID: SnapshotID? = nil,
                       structure: Structure? = nil,
                       parent: ObjectID? = nil,
                       children: [ObjectID] = [],
                       attributes: [String:Variant]=[:],
                       components: [any Component]=[]) -> MutableObject {
        precondition(state == .transient)
        
        let actualID = design.allocateID(required: id)
        let actualSnapshotID = design.allocateID(required: snapshotID)
        
        let actualStructure: Structure
        switch type.structuralType {
        case .unstructured:
            precondition(structure == nil || structure == .unstructured,
                         "Structural component mismatch for type \(type.name). Got: \(structure!.type) expected: \(type.structuralType)")
            actualStructure = .unstructured
        case .node:
            precondition(structure == nil || structure == .node,
                         "Structural component mismatch for type \(type.name). Got: \(structure!.type) expected: \(type.structuralType)")
            actualStructure = .node
        case .edge:
            guard let structure else {
                fatalError("Structural component of type `edge` is required to be provided for type \(type.name)")
            }
            
            precondition(structure.type == .edge,
                         "Structural component mismatch for type \(type.name). Got: \(structure.type) expected: \(type.structuralType)")
            
            actualStructure = structure
        }
        var actualAttributes = attributes
        
        // Add required components as described by the object type.
        //
        for attribute in type.attributes {
            if actualAttributes[attribute.name] == nil {
                actualAttributes[attribute.name] = attribute.defaultValue
            }
        }
        
        let snapshot = MutableObject(id: actualID,
                                     snapshotID: actualSnapshotID,
                                     type: type,
                                     structure: actualStructure,
                                     parent: parent,
                                     children: children,
                                     attributes: actualAttributes,
                                     components: components)
        
        self.objects[actualID] = .mutable(snapshot)
        self.snapshotIDs.insert(actualSnapshotID)
        self.removedObjects.remove(actualID)
        
        return snapshot
    }
    
    /// Insert an object snapshot to a frame while maintaining referential
    /// integrity.
    ///
    /// - Parameters:
    ///     - snapshot: Snapshot to be inserted.
    ///
    /// Requirements for the snapshot:
    ///
    /// - ID and snapshot ID must not be present in the frame
    /// - mutable must be owned, immutable must not be owned
    /// - structural dependencies must be satisfied
    ///
    /// If the requirements are not met, then it is considered a programming
    /// error.
    ///
    /// - Precondition: References such as edge endpoints, parent, children
    ///   must be valid within the frame.
    ///
    /// - SeeAlso: ``Frame/brokenReferences(snapshot:)``,
    ///
    public func insert(_ snapshot: DesignObject) {
        // Check for referential integrity
        
        if case let .edge(origin, target) = snapshot.structure {
            precondition(contains(origin), "Missing origin object in frame")
            precondition(contains(target), "Missing target object in frame")
        }
        guard snapshot.children.allSatisfy({ contains($0) }) else {
            preconditionFailure("Missing children in frame")
            
        }
        guard let parent = snapshot.parent, contains(parent) else {
            preconditionFailure("Missing parent in frame")
        }
        
        unsafeInsert(snapshot)
    }
    
    /// Unsafely insert a snapshot to the frame, not checking for structural
    /// references.
    ///
    /// This method is intended to be used by batch-loading of objects
    /// into the frame where the caller adds objects in an order when
    /// referential integrity might not be assured unless the whole
    /// batch is loaded. Frame with broken referential integrity can not
    /// be accepted by the object design (``Design/accept(_:appendHistory:)``.
    ///
    /// It is rather rare to use this method. Typically one would
    /// use the ``insert(_:)`` method.
    ///
    /// - Parameters:
    ///     - snapshot: Snapshot to be inserted.
    ///
    /// - Precondition: Frame must be transient, must not contain snapshot with
    ///   the same ID or with the same snapshot ID.
    ///
    /// - SeeAlso: ``TransientFrame/insert(_:)``
    ///
    public func unsafeInsert(_ snapshot: DesignObject) {
        precondition(state == .transient)
        precondition(objects[snapshot.id] == nil,
                     "Inserting duplicate object ID \(snapshot.id) to frame \(id)")
        precondition(!snapshotIDs.contains(snapshot.snapshotID),
                     "Inserting duplicate snapshot ID \(snapshot.id) to frame \(id)")
        
        objects[snapshot.id] = .stable(snapshot)
        snapshotIDs.insert(snapshot.snapshotID)
        
        if originalIDs.contains(snapshot.id) {
            removedObjects.remove(snapshot.id)
        }
    }
    
    /// Remove an object from the frame and all its dependants.
    ///
    /// The method removes the object with given object ID. Then traverses
    /// and removes all the objects that depend on the removed object.
    ///
    /// All object's children will be removed as well.
    ///
    /// All parents from which an object is removed will be mutated using
    /// ``mutate(_:)``.
    ///
    /// - Returns: A list of objects removed from the frame except the object
    ///   asked to be removed.
    ///
    /// - Complexity: Worst case O(n^2), typically O(n).
    ///
    /// - Precondition: The frame must contain object with given ID.
    /// - Precondition: The frame state must be ``State/transient``.
    ///
    @discardableResult
    public func removeCascading(_ id: ObjectID) -> Set<ObjectID> {
        precondition(state == .transient)
        precondition(contains(id),
                     "Unknown object ID \(id) in frame \(self.id)")
        
        var removed: Set<ObjectID> = Set()
        var scheduled: Set<ObjectID> = [id]
        
        while !scheduled.isEmpty {
            let garbageID = scheduled.removeFirst()
            let garbage = objects[garbageID]!.asStable()
            
            objects[garbage.id] = nil
            snapshotIDs.remove(garbage.snapshotID)
            
            if originalIDs.contains(garbage.id) {
                removedObjects.insert(garbage.id)
            }
            
            removed.insert(garbageID)
            
            if let parentID = garbage.parent, !removed.contains(parentID) {
                let parent = mutate(parentID)
                parent.removeChild(garbageID)
            }
            for child in garbage.children where !removed.contains(child) {
                scheduled.insert(child)
            }
            
            // Check for dependants (edges)
            //
            for dependant in snapshots where !removed.contains(dependant.id) {
                if case let .edge(origin, target) = dependant.structure {
                    if garbage.id == origin || garbage.id == target {
                        scheduled.insert(dependant.id)
                    }
                }
            }
        }
        return removed
    }
    
    /// Validate structural references.
    ///
    /// The method validates structural integrity of objects:
    ///
    /// - Edge endpoints must exist within the frame.
    /// - Children-parent relationship must be mutual.
    /// - There must be no parent-child cycle.
    ///
    /// If the validation fails, detailed information can be provided by the ``brokenReferences()``
    /// method.
    ///
    /// - SeeAlso: ``accept()``, ``Design/accept(_:appendHistory:)``
    /// - Precondition: The frame must be in transient state – must not be
    ///   previously accepted or discarded.
    ///
    public func validateStructure() throws (TransientFrameError) {
        // TODO: Check object types and attributes here
        precondition(state == .transient)
        
        var parents: [(parent: ObjectID, child: ObjectID)] = []
        
        // Integrity checks
        for (checkedID, checked) in self.objects {
            // Check references
            if let (origin, target) = checked.edgeEndpoints {
                guard let origin = objects[origin], let target = objects[target] else {
                    throw .brokenEdgeEndpoint
                }
                
                guard origin.structure == .node && target.structure == .node else {
                    throw .edgeEndpointNotANode
                }
            }
            
            for childID in checked.children {
                guard let child = objects[childID] else {
                    throw .brokenChild
                }
                guard child.parent == checkedID else {
                    throw .parentChildMismatch
                }
            }
            
            if let parentID = checked.parent {
                guard let parent = objects[parentID] else {
                    throw .brokenParent
                }
                guard parent.children.contains(checkedID) else {
                    throw .parentChildMismatch
                }
                parents.append((parent: parentID, child: checkedID))
            }
        }
        
        // Map: child -> parent
        
        let children = Set(parents.map { $0.child })
        var tops: [ObjectID] = parents.compactMap {
            if children.contains($0.parent) {
                nil
            }
            else {
                $0.parent
            }
        }
        
        while !tops.isEmpty {
            let topParent = tops.removeFirst()
            for (_, child) in parents.filter({ $0.parent == topParent }) {
                tops.append(child)
            }
            parents.removeAll { $0.parent == topParent }
        }
        
        if !parents.isEmpty {
            throw .parentChildCycle
        }
    }
    
    /// Accept objects in the transient frame.
    ///
    /// Validates the object structure and returns list of stable design objects if the structure is
    /// valid. See ``validateStructure()`` for more information about structure validation.
    ///
    /// If the structure was valid, the frame will be marked as _accepted_ and will no longer be
    /// mutable.
    ///
    /// - Returns: list of immutable design objects.
    /// - Precondition: Frame state must be transient.
    /// - SeeAlso: ``validateStructure()``, ``Design/accept(_:appendHistory:)``
    ///
    public func accept() throws (TransientFrameError) -> [DesignObject] {
        precondition(state == .transient)
        
        try validateStructure()
        self.state = .accepted
        
        return objects.values.map { $0.asStable() }
    }
    
    /// Mark the frame as discarded and reject any further modifications.
    ///
    /// - Precondition: The frame state must be ``State/transient``.
    ///
    public func discard() {
        precondition(state == .transient)
        self.state = .discarded
    }
    
    /// Make a snapshot mutable within the frame.
    ///
    /// If the snapshot is already mutable and is owned by the frame, then it is
    /// returned as is. If the snapshot is not owned by the frame, then it is
    /// derived first and the derived snapshot is returned.
    ///
    /// - Parameters:
    ///     - id: Object ID of the object to be derived.
    ///
    /// The new snapshot will be assigned a new snapshot ID from the shared
    /// identity generator of the associated design.
    ///
    /// - Returns: Newly derived object snapshot.
    ///
    /// - Precondition: The frame must contain an object with given ID.
    /// - Precondition: The frame state must be ``State/transient``.
    ///
    public func mutate(_ id: ObjectID) -> MutableObject {
        precondition(state == .transient)
        
        guard let current = self.objects[id] else {
            preconditionFailure("No object with ID \(id) in frame ID \(self.id)")
        }
        switch current {
        case .mutable(let snapshot):
            return snapshot
        case .stable(let original):
            let derivedSnapshotID: SnapshotID = design.allocateID()
            let derived = MutableObject(id: original.id,
                                        snapshotID: derivedSnapshotID,
                                        type: original.type,
                                        structure: original.structure,
                                        parent: original.parent,
                                        children: original.children.items,
                                        attributes: original.attributes,
                                        components: original.components.components)
            
            self.objects[id] = .mutable(derived)
            self.snapshotIDs.remove(original.snapshotID)
            self.snapshotIDs.insert(derived.snapshotID)
            
            return derived
        }
    }
    
    /// Checks whether the object is marked as mutable.
    ///
    /// - SeeAlso: ``mutate(_:)``
    ///
    public func isMutable(_ id: ObjectID) -> Bool {
        guard let ref = objects[id] else {
            preconditionFailure("Frame \(self.id) has no object \(id)")
        }
        switch ref {
        case .stable(_): return false
        case .mutable(_): return true
        }
    }
    
    // MARK: - Hierarchy
    //
    
    /// Assign a child to a parent object.
    ///
    /// This is a mutating function – it creates a mutable version of
    /// both parent and a child.
    ///
    /// - Precondition: The child object must not have a parent.
    /// - ToDo: Check for cycles.
    ///
    /// - SeeAlso: ``ObjectSnapshot/children``, ``ObjectSnapshot/parent``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    public func addChild(_ childID: ObjectID, to parentID: ObjectID) {
        let parent = self.mutate(parentID)
        let child = self.mutate(childID)
        
        precondition(child.parent == nil)
        
        child.parent = parentID
        parent.addChild(childID)
    }
    
    /// Remove an object `childID` from parent `parentID`.
    ///
    /// The child is removed from the list of children of the parent. Child's
    /// parent will be set to `nil`.
    ///
    /// This is a mutating function – it creates a mutable version of
    /// both parent and a child.
    ///
    /// The object will remain in the frame, will not be deleted.
    ///
    /// - SeeAlso: ``ObjectSnapshot/children``, ``ObjectSnapshot/parent``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    public func removeChild(_ childID: ObjectID, from parentID: ObjectID) {
        let parent = self.mutate(parentID)
        let child = self.mutate(childID)
        
        precondition(child.parent == parentID)
        precondition(parent.children.contains(childID))
        
        parent.removeChild(childID)
        child.parent = nil
    }
    
    /// Move a child to a different parent.
    ///
    /// If the child has a parent, then the child will be removed from the
    /// parent's children list.
    ///
    /// This is a mutating function – it creates a mutable version of
    /// a child. Mutable version of the old parent will be created, if
    /// necessary.
    ///
    /// - SeeAlso: ``ObjectSnapshot/children``, ``ObjectSnapshot/parent``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    public func setParent(_ childID: ObjectID, to parentID: ObjectID?) {
        let child = mutate(childID)
        if let originalParentID = child.parent {
            mutate(originalParentID).removeChild(childID)
        }
        child.parent = parentID
        if let parentID {
            mutate(parentID).addChild(childID)
        }
    }
    
    /// Removes a child from its parent.
    ///
    /// If the child has a parent, it will be removed from the parent's children
    /// list.
    ///
    /// This is a mutating function – it creates a mutable version of
    /// a child. Mutable version of the old parent will be created, if
    /// necessary.
    ///
    /// The object will remain in the frame, will not be deleted.
    ///
    /// - SeeAlso: ``ObjectSnapshot/children``, ``ObjectSnapshot/parent``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    public func removeFromParent(_ childID: ObjectID) {
        let child = self[childID]
        guard let parentID = child.parent else {
            return
        }
        let parent = self[parentID]
        guard parent.children.contains(childID) else {
            return
        }
        
        mutate(parentID).removeChild(childID)
        mutate(childID).parent = nil
    }
    
    // Graph Protocol
    public var edgeIDs: [ObjectID] {
        objects.compactMap { (id, ref) in
            ref.structure.type == .edge ? id : nil
        }
    }

    public var nodeIDs: [ObjectID] {
        objects.compactMap { (id, ref) in
            ref.structure.type == .node ? id : nil
        }
    }

}


