//
//  TransientFrame.swift
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

/// Transient frame is frame that can be modified.
///
/// Transient frames are created using ``Design/createFrame(deriving:id:)``.
///
/// Multiple changes are applied to a transient frame, which can be then
/// validated and turned into a stable frame using ``Design/accept(_:appendHistory:)``.
/// If the changes can not be validated or for any other reason the changes
/// are not to be accepted, the frame can be discarded by ``Design/discard(_:).
///
/// Transient frames are not persisted, they exist only during runtime.
///
/// The changes that can be performed with the transient frame:
///
/// - Add objects with ``TransientFrame/create(_:structure:attributes:components:)``
///    or ``TransientFrame/insert(_:)``.
/// - Mutate existing objects in the frame using
///   ``TransientFrame/mutableObject(_:)``.
/// - Change parent/child hierarchy.
///
/// Once the frame is accepted or discarded, it can no longer be modified.
///
public class TransientFrame: Frame {
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
    
    var objects: [ObjectID:SnapshotReference]

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

    /// List of snapshots in the frame.
    ///
    /// - Note: The order of the snapshots is arbitrary. Do not rely on it.
    ///
    public var snapshots: [ObjectSnapshot] {
        return self.objects.values.map { $0.snapshot }
    }
    
    /// Returns `true` if the frame contains an object with given object ID.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return self.objects[id] != nil
    }
    
    /// Get an object version of object with identity `id`.
    ///
    /// - Precondition: Frame must contain object with given ID.
    ///
    public func object(_ id: ObjectID) -> ObjectSnapshot {
        guard let ref = objects[id] else {
            preconditionFailure("Invalid object ID \(id) in frame \(self.id)")
        }
        return ref.snapshot
    }
   
    /// Get an object version of object with identity `id`.
    ///
    public subscript(id: ObjectID) -> ObjectSnapshot {
        get {
            return object(id)
        }
    }

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
        var originals: Set<ObjectID> = Set()
        
        if let snapshots {
            for snapshot in snapshots {
                let ref = SnapshotReference(snapshot: snapshot,
                                            owned: false)
                self.objects[snapshot.id] = ref
                self.snapshotIDs.insert(snapshot.snapshotID)
                originals.insert(snapshot.id)
            }
        }
        self.originalIDs = originals
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
    /// - Precondition: References such as edge endpoints, parent, children
    ///   must be valid within the frame.
    ///
    /// - SeeAlso: ``Frame/brokenReferences(snapshot:)``, ``TransientFrame/unsafeInsert(_:owned:)``
    ///
    public func insert(_ snapshot: ObjectSnapshot) {
        // Check for referential integrity
        guard brokenReferences(snapshot: snapshot).isEmpty else {
            preconditionFailure("Trying to insert an object that contains invalid references")
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
    /// - SeeAlso: ``TransientFrame/insert(_:)``
    ///
    public func unsafeInsert(_ snapshot: ObjectSnapshot, owned: Bool = false) {
        precondition(state == .transient)
        precondition(snapshot.state != .transient)
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
        
        if originalIDs.contains(snapshot.id) {
            removedObjects.remove(snapshot.id)
        }
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
        precondition(state == .transient)
        
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
        precondition(state == .transient)
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
                let parent = mutate(parentID)
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
    
    internal func _remove(_ snapshot: ObjectSnapshot) {
        precondition(state == .transient)
        objects[snapshot.id] = nil
        snapshotIDs.remove(snapshot.snapshotID)

        if originalIDs.contains(snapshot.id) {
            removedObjects.insert(snapshot.id)
        }
    }
    
    /// Mark the frame as accepted and reject any further modifications.
    ///
    /// Also mark all owned objects as ``VersionState/validated``.
    ///
    public func markAccepted() {
        precondition(state == .transient)

        for ref in objects.values {
            if ref.owned {
                ref.snapshot.promote(.validated)
            }
        }
        
        self.state = .accepted
    }
    
    /// Mark the frame as discarded and reject any further modifications.
    ///
    public func markDiscarded() {
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
    /// - Precondition: The frame is not frozen. See ``promote(_:)``.
    ///
    public func mutate(_ id: ObjectID) -> ObjectSnapshot {
        precondition(state == .transient)

        guard let originalRef = self.objects[id] else {
            preconditionFailure("No object with ID \(id) in frame ID \(self.id)")
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
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    public func addChild(_ childID: ObjectID, to parentID: ObjectID) {
        let parent = self.mutate(parentID)
        let child = self.mutate(childID)
        
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
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    public func removeChild(_ childID: ObjectID, from parentID: ObjectID) {
        let parent = self.mutate(parentID)
        let child = self.mutate(childID)

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
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    public func setParent(_ childID: ObjectID, to parentID: ObjectID?) {
        let child = mutate(childID)
        if let originalParentID = child.parent {
            mutate(originalParentID).children.remove(childID)
        }
        child.parent = parentID
        if let parentID {
            mutate(parentID).children.add(childID)
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
    public func removeFromParent(_ childID: ObjectID) {
        let child = self[childID]
        guard let parentID = child.parent else {
            return
        }
        let parent = self[parentID]
        guard parent.children.contains(childID) else {
            return
        }
        
        mutate(parentID).children.remove(childID)
        mutate(childID).parent = nil
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
}


