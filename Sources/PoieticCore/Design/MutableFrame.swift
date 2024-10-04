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
/// - Add objects to the frame using ``MutableFrame/create(_:structure:attributes:components:)``
///    or ``MutableFrame/insert(_:)``.
/// - Mutate existing objects in the frame using
///   ``MutableFrame/mutableObject(_:)``.
///
/// Completed change set is expected to be accepted to the design using
/// ``Design/accept(_:appendHistory:)``.
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
   
    public subscript(id: ObjectID) -> ObjectSnapshot {
        get {
            return object(id)
        }
    }
    
    /// Design with which this frame is associated with.
    ///
    public unowned let design: Design
    
    /// ID of the frame.
    ///
    /// The ID is unique within the design.
    ///
    public let id: FrameID

    // TODO: Remove state or change to FrameState: open, accepted, discarded
    var state: VersionState = .transient
    
    /// Frame objects.
    ///
    var objects: [ObjectID:SnapshotReference]

    /// Cache of snapshot IDs used to verify unique ownership
    ///
    var snapshotIDs: Set<SnapshotID>
    
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
    /// ``mutableObject(_:)``.
    ///
    /// Snapshots removed from the mutable frame are only disassociated with the
    /// frame, not removed from the design or any other frame.
    ///
    public init(design: Design,
                id: FrameID,
                snapshots: [ObjectSnapshot]? = nil) {
        self.design = design
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
    ///
    /// Requirements for the snapshot:
    ///
    /// - snapshot state must not be ``VersionState/transient``
    /// - ID and snapshot ID must not be present in the frame
    /// - mutable must be owned, immutable must not be owned
    /// - structural dependencies must be satisfied
    ///
    /// If the requirements are not met, then it is considered a programming
    /// error.
    ///
    /// - SeeAlso: ``Frame/brokenReferences(snapshot:)``, ``MutableFrame/unsafeInsert(_:owned:)``
    ///
    public func insert(_ snapshot: ObjectSnapshot) {
        // Check for referential integrity
        guard brokenReferences(snapshot: snapshot).isEmpty else {
            fatalError("Trying to insert an object that contains invalid references. Hint: Check structure, children or parent.")
        }
        unsafeInsert(snapshot, owned: true)
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
    /// Requirements for the snapshot:
    ///
    /// - snapshot state must not be ``VersionState/transient``
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
    /// - SeeAlso: ``MutableFrame/insert(_:)``
    ///
    public func unsafeInsert(_ snapshot: ObjectSnapshot, owned: Bool = false) {
        precondition(state.isMutable,
                     "Trying to modify a frame that is not mutable")
        precondition(snapshot.state != .transient,
                     "Trying to insert an unstable object")
        precondition(objects[snapshot.id] == nil,
                     "Trying to insert an object with object ID \(snapshot.id) that already exists in frame \(id)")
        precondition(!snapshotIDs.contains(snapshot.snapshotID),
                     "Trying to insert an object with snapshot ID \(snapshot.snapshotID) that already exists in frame \(id)")
        
        // Make sure we do not own immutable objects.
        // This can be put into one condition, however we split it for better error understanding
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
    /// The new object ID is generated from the identity generator.
    ///
    /// - Parameters:
    ///     - type: Type of the object to be created.
    ///     - attributes: Attribute dictionary to be used for object
    ///       initialization.
    ///     - structure: Structural component of the new object that must match
    ///       the object type.
    ///    - components: List of components to be associated with the newly
    ///       created object.
    ///
    /// - Note: Attributes are not checked according to the object type during
    ///   object creation. The object is not yet required to satisfy any
    ///   constraints.
    ///
    /// - Returns: Object ID of the newly created object.
    ///
    /// - Precondition: The frame is not frozen. See ``promote(_:)``.
    ///
    /// - SeeAlso: ``Design/createSnapshot(_:id:snapshotID:attributes:components:structure:state:)``,
    ///   ``ObjectSnapshot/init(id:snapshotID:type:structure:components:)
    ///
    public func create(_ type: ObjectType,
                       structure: StructuralComponent? = nil,
                       attributes: [String:Variant] = [:],
                       components: [any Component] = []) -> ObjectID {
        precondition(state.isMutable)
        
        let snapshot = design.createSnapshot(type,
                                             structure: structure,
                                             attributes: attributes,
                                             components: components)
        insert(snapshot)
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
    /// - Precondition: The frame is not frozen. See ``promote(_:)``.
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
    

    /// Promote the frame to a state that is higher than the current
    /// state.
    ///
    /// This is called by the design when the frame is accepted.
    ///
    public func promote(_ state: VersionState) {
        precondition(self.state < state,
                     "Can not promote from state \(self.state) to \(state)")
        for ref in objects.values {
            if ref.owned {
                ref.snapshot.promote(state)
            }
        }
        
        self.state = state
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
    /// identity generator of the associated design.
    ///
    /// - Returns: Newly derived object snapshot.
    /// 
    /// - Precondition: The frame must contain an object with given ID.
    /// - Precondition: The frame is not frozen. See ``promote(_:)``.
    ///
    public func mutableObject(_ id: ObjectID) -> ObjectSnapshot {
        precondition(state.isMutable, "Trying to modify a frozen frame")
        
        guard let originalRef = self.objects[id] else {
            fatalError("No object with ID \(id) in frame ID \(self.id)")
        }
        if originalRef.owned {
            return originalRef.snapshot
        }
        else {
            let derived = design.deriveSnapshot(originalRef.snapshot.snapshotID)

            let ref = SnapshotReference(snapshot: derived, owned: true)
            self.objects[id] = ref
            self.snapshotIDs.remove(originalRef.snapshot.snapshotID)
            self.snapshotIDs.insert(derived.snapshotID)

            return derived
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
        let child = self[childID]
        guard let parentID = child.parent else {
            return
        }
        let parent = self[parentID]
        guard parent.children.contains(childID) else {
            return
        }
        
        mutableObject(parentID).children.remove(childID)
        mutableObject(childID).parent = nil
    }

}


