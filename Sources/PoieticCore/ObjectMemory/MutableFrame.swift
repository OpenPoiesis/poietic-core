//
//  MutableFrame.swift
//  
//
//  Created by Stefan Urbanek on 23/03/2023.
//

struct SnapshotReference {
    let snapshot: ObjectSnapshot
    
    /// Flag whether the snapshot reference is owned by the mutable frame and
    /// therefore can be mutated. Snapshots that are not owned by the frame can
    /// not be mutated.
    ///
    /// Un-owned snapshots are expected to be stable.
    let owned: Bool
}

/// Mutable frame is a version frame that can be changed - mutated.
///
/// Mutable frame represents a design version where changes can be applied
/// and grouped together. It is somewhat analogous to a transaction.
///
/// The basic changes that can be done with a mutable frame:
///
/// - Add objects to the frame using ``MutableFrame/create(_:structuralReferences:components:)``
///    or ``MutableFrame/insert(_:owned:)``.
/// - Mutate existing objects in the frame using
///   ``MutableFrame/mutableObject(_:)``.
///
/// Completed change set is expected to be accepted to the memory using
/// ``ObjectMemory/accept(_:appendHistory:)``.
///
public class MutableFrame: Frame {
    /// List of snapshots in the frame.
    ///
    /// - Note: The order of the snapshots is arbitrary. Do not rely on it.
    ///
    public var snapshots: [ObjectSnapshot] {
        return self.objects.values.map { $0.snapshot }
    }
    
    /// Returns `true` if the frame contains a snapshot with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return self.objects[id] != nil
    }
    
    /// Get an object version of object with identity `id`.
    ///
    public func object(_ id: ObjectID) -> ObjectSnapshot {
        guard let ref = objects[id] else {
            fatalError("Invalid object ID \(id) in frame \(self.id).")
        }
        return ref.snapshot
    }
    
    /// Object memory with which this frame is associated with.
    ///
    public unowned let memory: ObjectMemory
    
    /// ID of the frame.
    ///
    /// The ID is unique within the memory.
    ///
    public let id: FrameID

    // TODO: Remove state or change to FrameState: open, accepted, discarded
    var state: VersionState = .uninitialized
    
    var snapshotIDs: Set<SnapshotID>
    var objects: [ObjectID:SnapshotReference]
    
    
    // TODO: Include only objects that were NOT present in the original frame.
    /// A set of objects that were removed from the frame.
    ///
    public internal(set) var removedObjects: Set<ObjectID> = Set()

    /// List of object snapshots that were inserted to this frame or were
    /// derived for the purpose of mutation.
    ///
    /// - Note: If an object was derived for mutation, but not changed, it
    ///   will still appear in this list.
    ///
    var derivedObjects: [ObjectSnapshot] {
        return objects.values.filter {
            $0.owned
        }
        .map {
            $0.snapshot
        }
    }
    
    /// Flag whether the mutable frame has any changes.
    public var hasChanges: Bool {
        (!removedObjects.isEmpty || !derivedObjects.isEmpty)
    }
    
    /// Create a new mutable frame.
    ///
    /// Creates a new mutable frame that will be associated with the `memory`.
    ///
    /// - Parameters:
    ///     - memory: The memory the frame will be associated with.
    ///     - id: ID of the frame. Must be unique within the memory.
    ///     - snapshots: List of snapshots to be associated with the frame.
    ///
    /// The frame will contain all the provided snapshots, but will not own
    /// them. The frame will own only snapshots inserted directly to the frame
    /// using ``insertDerived(_:id:)`` or by deriving an object using
    /// ``mutableObject(_:)``.
    ///
    /// Snapshots removed from the mutable frame are only disassociated with the
    /// frame, not removed from the memory or any other frame.
    ///
    public init(memory: ObjectMemory,
                id: FrameID,
                snapshots: [ObjectSnapshot]? = nil) {
        self.memory = memory
        self.id = id
        self.objects = [:]
        self.snapshotIDs = Set()

        if let snapshots {
            for snapshot in snapshots {
                let ref = SnapshotReference(snapshot: snapshot,
                                            owned: false)
                self.objects[snapshot.id] = ref
                self.snapshotIDs.insert(snapshot.snapshotID)
            }
        }
    }
    
    /// Insert an object snapshot to a frame while maintaining referential
    /// integrity.
    ///
    /// - Parameters:
    ///     - snapshot: Snapshot to be inserted.
    ///     - owned: Flag whether the snapshot will be owned by the frame or
    ///              not.
    ///
    /// Requirements for the snapshot:
    ///
    /// - snapshot state must not be ``VersionState/uninitialized``
    /// - ID and snapshot ID must not be present in the frame
    /// - mutable must be owned, immutable must not be owned
    /// - structural dependencies must be satisfied
    ///
    /// If the requirements are not met, then it is considered a programming
    /// error.
    ///
    /// - SeeAlso: ``Frame/brokenReferences(snapshot:)``, ``MutableFrame/unsafeInsert(_:owned:)``
    ///
    public func insert(_ snapshot: ObjectSnapshot, owned: Bool = false) {
        // Check for referential integrity
        guard brokenReferences(snapshot: snapshot).isEmpty else {
            fatalError("Trying to insert an object that contains invalid references. Hint: Check structure, children or parent.")
        }
        unsafeInsert(snapshot, owned: owned)
    }
    
    /// Unsafely insert a snapshot to the frame, not checking for structural
    /// references.
    ///
    /// This method is intended to be used by batch-loading of objects
    /// into the frame where the caller adds objects in an order when
    /// referential integrity might not be assured unless the whole
    /// batch is loaded. Frame with broken referential integrity can not
    /// be accepted by the object memory (``ObjectMemory/accept(_:appendHistory:)``.
    ///
    /// It is rather rare to use this method. Typically one would
    /// use the ``insert(_:owned:)`` method.
    ///
    /// Requirements for the snapshot:
    ///
    /// - snapshot state must not be ``VersionState/uninitialized``
    /// - ID and snapshot ID must not be present in the frame
    /// - mutable must be owned, immutable must not be owned
    ///
    /// If the requirements are not met, then it is considered a programming
    /// error.
    ///
    /// - Parameters:
    ///     - snapshot: Snapshot to be inserted.
    ///     - owned: Flag whether the snapshot will be owned by the frame or
    ///              not.
    ///
    /// - SeeAlso: ``MutableFrame/insert(_:owned:)``
    ///
    public func unsafeInsert(_ snapshot: ObjectSnapshot, owned: Bool = false) {
        precondition(state.isMutable,
                     "Trying to modify a frame that is not mutable")
        precondition(snapshot.state != .uninitialized,
                     "Trying to insert an unstable object")
        precondition(objects[snapshot.id] == nil,
                     "Trying to insert an object with object ID \(snapshot.id) that already exists in frame \(id)")
        precondition(!snapshotIDs.contains(snapshot.snapshotID),
                     "Trying to insert an object with snapshot ID \(snapshot.snapshotID) that already exists in frame \(id)")
        // FIXME: Test whether the object is owned by the memory
        
        // Make sure we do not own immutable objects.
        // This can be put into one condition, however we split it for better error understanding
        // TODO: This seems like historical remnant. No need for the "owned" flag any more? It relates to the mutability of the snapshot.
        precondition(!owned || (owned && snapshot.state.isMutable),
                     "Inserting mutable object must be owned by the frame")
        precondition(owned || (!owned && !snapshot.state.isMutable),
                     "Inserting immutable object must not be owned by the frame")

        let ref = SnapshotReference(snapshot: snapshot,
                                    owned: owned)

        objects[snapshot.id] = ref
        snapshotIDs.insert(snapshot.snapshotID)
    }
    
    
    /// Create a new object within the frame.
    ///
    /// The method creates a new objects, assigns provided components and
    /// creates all necessary components as defined by the object type, if
    /// not explicitly provided.
    ///
    /// The new object ID is generated from the shared object memory identity
    /// generator.
    ///
    /// - Parameters:
    ///     - type: Type of the object to be created.
    ///     - components: List of components to be associated with the newly
    ///       created object.
    ///
    /// - Returns: Object ID of the newly created object.
    ///
    /// - Precondition: The frame is not frozen. See ``freeze()``.
    ///
    /// - SeeAlso: ``ObjectMemory/createSnapshot(_:id:snapshotID:components:structure:initialized:)``,
    ///   ``ObjectSnapshot/init(id:snapshotID:type:structure:components:)
    ///
    public func create(_ type: ObjectType,
                       structure: StructuralComponent? = nil,
                       components: [any Component] = []) -> ObjectID {
        precondition(state.isMutable)
        
        let snapshot = memory.createSnapshot(type,
                                             components: components,
                                             structure: structure)
        insert(snapshot, owned: true)
        return snapshot.id
    }
    
    /// Remove an object from the frame and all its dependants.
    ///
    /// The method removes the object with given object ID. Then traverses
    /// and removes all the objects that depend on the removed object.
    ///
    /// All object's children will be removed as well.
    ///
    /// All parents from which an object is removed will be mutated using
    /// ``mutableObject(_:)``.
    ///
    /// - Returns: A list of objects removed from the frame except the object
    ///   asked to be removed.
    ///
    /// - Complexity: Worst case O(n^2), typically O(n).
    ///
    /// - Precondition: The frame must contain object with given ID.
    /// - Precondition: The frame is not frozen. See ``freeze()``.
    ///
    @discardableResult
    public func removeCascading(_ id: ObjectID) -> Set<ObjectID> {
        precondition(state.isMutable)
        precondition(contains(id),
                     "Unknown object ID \(id) in frame \(self.id)")
        
        var removed: Set<ObjectID> = Set()
        var scheduled: Set<ObjectID> = [id]

        while !scheduled.isEmpty {
            let garbageID = scheduled.removeFirst()
            let garbage = objects[garbageID]!.snapshot
            _remove(garbage)
            removed.insert(garbageID)
            
            if let parentID = garbage.parent, !removed.contains(parentID) {
                let parent = mutableObject(parentID)
                parent.children.remove(garbageID)
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
    

    public func debugPrint() {
        print("-- FRAME \(id)")
        print("SNAPSHOTS:")
        for snapshot in self.snapshots {
            let isOwned: String
            
            if objects[snapshot.id]!.owned {
                isOwned = "*"
            }
            else {
                isOwned = ""
            }

            let children = snapshot.children.map { String($0) }
                .joined(separator: ",")
            let deps = snapshot.structure.description
            
            print("\(snapshot.id).\(snapshot.snapshotID)\(isOwned): str[\(deps)] children[\(children)]")
        }
        if removedObjects.isEmpty {
            print("NO REMOVED OBJECTS")
        }
        else {
            let removedStr = removedObjects.map { String($0) }
                .joined(separator: ",")

            print("REMOVED: \(removedStr)")
        }
        print("-- END OF FRAME \(id)")
    }

    internal func _remove(_ snapshot: ObjectSnapshot) {
        precondition(state.isMutable)
        objects[snapshot.id] = nil
        snapshotIDs.remove(snapshot.snapshotID)
        removedObjects.insert(id)
    }
    

    /// Freeze the frame so it can no longer be mutated.
    ///
    /// This is called by the object memory when the frame is accepted.
    ///
    public func freeze() {
        precondition(state.isMutable)
        for ref in objects.values {
            if ref.owned {
                ref.snapshot.freeze()
            }
        }
        
        self.state = .frozen
    }
       
    /// Return a snapshot that can be mutated.
    ///
    /// If the snapshot is mutable and is owned by the frame, then it is
    /// returned as is. If the snapshot is not owned by the frame, then it is
    /// derived first and the derived snapshot is returned.
    ///
    /// - Parameters:
    ///     - id: Object ID of the object to be derived.
    ///
    /// The new snapshot will be assigned a new snapshot ID from the shared
    /// identity generator of the associated object memory.
    ///
    /// - Returns: Newly derived object snapshot.
    /// 
    /// - Precondition: The frame must contain an object with given ID.
    /// - Precondition: The frame is not frozen. See ``freeze()``.
    ///
    public func mutableObject(_ id: ObjectID) -> ObjectSnapshot {
        // TODO: Replace this with just object() -> MutableObject as a reference
        precondition(state.isMutable, "Trying to modify a frozen frame")
        
        guard let originalRef = self.objects[id] else {
            fatalError("No object with ID \(id) in frame ID \(self.id)")
        }
        if originalRef.owned {
            return originalRef.snapshot
        }
        else {
            let original = originalRef.snapshot
            let derived = memory.allocateUnstructuredSnapshot(
                original.type,
                id: id
            )
            // TODO: Use initialize(..., components: ...)
            derived.components = original.components
            derived.initialize(structure: original.structure)

            let ref = SnapshotReference(snapshot: derived, owned: true)
            self.objects[id] = ref
            self.snapshotIDs.remove(originalRef.snapshot.snapshotID)
            self.snapshotIDs.insert(derived.snapshotID)

            return derived
        }
    }
    /// Set a node component.
    ///
    public func setComponent<T>(_ id: ObjectID, component: T) where T : Component {
        let object = self.mutableObject(id)
        object.components[T.self] = component
    }
    
    /// Get a mutable graph for the frame.
    ///
    /// The returned graph is an unbound graph - a view on top of the mutable
    /// frame. Any query of the graph is translated into a query of the frame
    /// at the same time.
    ///
    /// - SeeAlso: `MutableUnboundGraph`.
    ///
    public var mutableGraph: MutableGraph {
        MutableUnboundGraph(frame: self)
    }
    
    /// Get an immutable graph for the frame.
    ///
    /// The returned graph is an unbound graph - a view on top of the mutable
    /// frame. Any query of the graph is translated into a query of the frame
    /// at the same time.
    ///
    /// - SeeAlso: `UnboundGraph`.
    ///
    public var graph: Graph {
        UnboundGraph(frame: self)
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
    /// ``MutableFrame/removeChild(_:from:)``,
    /// ``MutableFrame/removeFromParent(_:)``,
    /// ``MutableFrame/removeCascading(_:)``.
    public func addChild(_ childID: ObjectID, to parentID: ObjectID) {
        let parent = self.mutableObject(parentID)
        let child = self.mutableObject(childID)
        
        precondition(child.parent == nil)
        
        child.parent = parentID
        parent.children.add(childID)
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
    /// ``MutableFrame/addChild(_:to:)``,
    /// ``MutableFrame/removeFromParent(_:)``,
    /// ``MutableFrame/removeCascading(_:)``.
    public func removeChild(_ childID: ObjectID, from parentID: ObjectID) {
        let parent = self.mutableObject(parentID)
        let child = self.mutableObject(childID)

        precondition(child.parent == parentID)
        precondition(parent.children.contains(childID))

        parent.children.remove(childID)
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
    /// ``MutableFrame/addChild(_:to:)``,
    /// ``MutableFrame/removeChild(_:from:)``,
    /// ``MutableFrame/removeFromParent(_:)``,
    /// ``MutableFrame/removeCascading(_:)``.
    public func setParent(_ childID: ObjectID, to parentID: ObjectID?) {
        let child = mutableObject(childID)
        if let originalParentID = child.parent {
            mutableObject(originalParentID).children.remove(childID)
        }
        child.parent = parentID
        if let parentID {
            mutableObject(parentID).children.add(childID)
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
    /// ``MutableFrame/addChild(_:to:)``,
    /// ``MutableFrame/removeChild(_:from:)``,
    /// ``MutableFrame/removeCascading(_:)``.
    public func removeFromParent(_ childID: ObjectID) {
        let child = object(childID)
        guard let parentID = child.parent else {
            return
        }
        let parent = object(parentID)
        guard parent.children.contains(childID) else {
            return
        }
        
        mutableObject(parentID).children.remove(childID)
        mutableObject(childID).parent = nil
    }

}


