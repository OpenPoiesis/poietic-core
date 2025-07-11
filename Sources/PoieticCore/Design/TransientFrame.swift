//
//  TransientFrame.swift
//  
//
//  Created by Stefan Urbanek on 23/03/2023.
//

/// Error thrown when validating and accepting a frame.
///
/// - SeeAlso: ``TransientFrame/validateStructure()``
/// 
public enum StructuralIntegrityError: Error {
    /// The frame contains references to objects that are not present in the frame.
    ///
    /// Use ``TransientFrame/brokenReferences()`` to investigate.
    ///
    case brokenStructureReference
    case brokenChild
    case brokenParent
    case parentChildMismatch
    case parentChildCycle
    case edgeEndpointNotANode // TODO: Rename to invalidStructureReferenceTargetType (or simpler)
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
    
    // validate also snapshot IDs
    @usableFromInline
    var _snapshots: EntityTable<_TransientSnapshotBox>
    @usableFromInline
    var _snapshotIDs: Set<ObjectID>
    
    @usableFromInline
    var _removedObjects: Set<ObjectID>
    var _reservations: Set<ObjectID>
    public var removedObjects: [ObjectID] { Array(_removedObjects) }
    
    public var mutableObjects: [TransientObject] {
        _snapshots.compactMap {
            guard case let .mutable(_, snapshot) = $0.content else {
                return nil
            }
            return snapshot
        }
    }
    
    public var objectIDs: [ObjectID] {
        _snapshots.map { $0.objectID }
    }

    /// List of snapshots in the frame.
    ///
    /// - Note: The order of the snapshots is arbitrary. Do not rely on it.
    ///
    public var snapshots: [ObjectSnapshot] {
        // TODO: [DEPRECATE] Review necessity of this, seems like used in tests only.
        _snapshots.map { $0.asSnapshot() }
    }
    
    /// Returns `true` if the frame contains an object with given object ID.
    ///
    public func contains(_ objectID: ObjectID) -> Bool {
        _snapshots[objectID] != nil
    }
    public func contains(snapshotID: ObjectID) -> Bool {
        _snapshotIDs.contains(snapshotID)
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
    public func object(_ id: ObjectID) -> ObjectSnapshot {
        // TODO: [DEPRECATE] Review necessity of this.
        guard let box = _snapshots[id] else {
            preconditionFailure("Unknown object \(id)")
        }
        return box.asSnapshot()
    }
    
    /// Get an object version of object with identity `id`.
    ///
    public subscript(id: ObjectID) -> ObjectSnapshot {
        get { object(id) }
    }
    
    /// Flag whether the mutable frame has any changes.
    public var hasChanges: Bool {
        return !removedObjects.isEmpty || _snapshots.contains { $0.hasChanges }
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
    /// - Precondition: Snapshots must have structural integrity and IDs must be unique.
    ///
    public init(design: Design,
                id: FrameID,
                snapshots: [ObjectSnapshot]? = nil) {
        // TODO: Either validate after init or rename argument snapshots: to unsafeSnapshots:
        self.design = design
        self.id = id
        self._snapshots = EntityTable()
        self._removedObjects = Set()
        self._reservations = []
        self._snapshotIDs = Set()
        
        if let snapshots {
            for snapshot in snapshots {
                let box = _TransientSnapshotBox(snapshot, isOriginal: false)
                _snapshots.insert(box)
                _snapshotIDs.insert(snapshot.snapshotID)
            }
        }
    }
    
    /// Mark the frame as accepted and use the ID reservations in the design identity manager.
    ///
    /// You typically do not need to call this method, it is called by
    /// ``Design/accept(_:appendHistory:)``.
    ///
    /// - SeeAlso: ``discard()``
    ///
    public func accept() {
        precondition(state == .transient)
        self.state = .accepted
    }
    
    /// Mark the frame as accepted and release ID reservations in the design identity manager.
    ///
    /// You typically do not need to call this method, it is called by
    /// ``Design/discard(_:)``.
    ///
    /// - SeeAlso: ``accept()``
    ///
    public func discard() {
        precondition(state == .transient)
        self.state = .discarded
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
    ///     - structure: Structural component of the new object. If not provided,
    ///       then unstructured is used.
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
    ///
    @discardableResult
    public func create(_ type: ObjectType,
                       objectID: ObjectID? = nil,
                       snapshotID: EntityID? = nil,
                       structure: Structure? = nil,
                       parent: ObjectID? = nil,
                       children: [ObjectID] = [],
                       attributes: [String:Variant]=[:],
                       components: [any Component]=[]) -> TransientObject {
        // IMPORTANT: Sync the logic (especially preconditions) as in RawDesignLoader.create(...)
        // TODO: Consider throwing an exception instead of having runtime errors
        precondition(state == .transient)
       
        let actualSnapshotID: ObjectID
        if let snapshotID {
            let success = design.identityManager.reserve(snapshotID, type: .snapshot)
            precondition(success, "Duplicate snapshot ID: \(snapshotID)")
            actualSnapshotID = snapshotID
        }
        else {
            actualSnapshotID = design.identityManager.createAndReserve(type: .snapshot)
        }
        _reservations.insert(actualSnapshotID)

        let actualID: ObjectID
        if let id = objectID {
            let success = design.identityManager.reserveIfNeeded(id, type: .object)
            precondition(success, "Entity type mismatch for ID \(id)")
            precondition(!self.contains(id), "Duplicate ID \(id)")
            actualID = id
        }
        else {
            actualID = design.identityManager.createAndReserve(type: .object)
        }
        _reservations.insert(actualID)

        let actualStructure = structure ?? .unstructured
        var actualAttributes = attributes
        
        // FIXME: [WIP] Is this the right place to add default attributes?
        for attribute in type.attributes {
            if actualAttributes[attribute.name] == nil {
                actualAttributes[attribute.name] = attribute.defaultValue
            }
        }
        
        let snapshot = TransientObject(type: type,
                                     snapshotID: actualSnapshotID,
                                     objectID: actualID,
                                     structure: actualStructure,
                                     parent: parent,
                                     children: children,
                                     attributes: actualAttributes,
                                     components: components)
        let box = _TransientSnapshotBox(snapshot, isNew: true)
        _snapshots.insert(box)
        _snapshotIDs.insert(snapshot.snapshotID)
        self._removedObjects.remove(actualID)
        
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
    public func insert(_ snapshot: ObjectSnapshot) {
        // TODO: Make insert() function throwing (StructuralIntegrityError)
        // Check for referential integrity
        // TODO: Validate structure vs. type
        do {
            try validateStructure(snapshot)
        }
        catch {
            preconditionFailure("Structural integrity error")
        }
        
        unsafeInsert(snapshot)
    }
    public func validateStructure(_ snapshot: ObjectSnapshot) throws (StructuralIntegrityError) {
        switch snapshot.structure {
        case .node, .unstructured: break
        case let .edge(origin, target):
            guard contains(origin) && contains(target) else {
                throw .brokenStructureReference
            }
        case let .orderedSet(owner, items):
            guard contains(owner) && items.allSatisfy({ contains($0) }) else {
                throw .brokenStructureReference
            }
        }
        guard snapshot.children.allSatisfy({ contains($0) }) else {
            throw .brokenChild
            
        }
        if let parent = snapshot.parent {
            guard contains(parent) else {
                throw .brokenParent
            }
        }
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
    internal func unsafeInsert(_ snapshot: ObjectSnapshot) {
        // TODO: [IMPORTANT] Check for snapshot ID existence
        precondition(state == .transient)
        precondition(!_snapshots.contains(snapshot.objectID),
                     "Inserting duplicate object ID \(snapshot.objectID) to frame \(id)")
        precondition(!_snapshotIDs.contains(snapshot.snapshotID),
                     "Inserting duplicate snapshot ID \(snapshot.snapshotID) to frame \(id)")
        precondition(_snapshots.allSatisfy { $0.snapshotID != snapshot.snapshotID },
                     "Inserting duplicate snapshot ID \(snapshot.objectID) to frame \(id)")
        
        let box = _TransientSnapshotBox(snapshot, isOriginal: false)
        _snapshots.insert(box)
        _snapshotIDs.insert(snapshot.snapshotID)
    }
    
    /// Insert snapshots into the transient frame together with reservations.
    ///
    /// This method is used by the loader. It consumes the reservations from the loader and takes
    /// responsibility for using them or releasing them.
    ///
    internal func unsafeInsert(_ snapshots: [ObjectSnapshot], reservations: some Collection<ObjectID>) {
        for snapshot in snapshots {
            unsafeInsert(snapshot)
        }
        _reservations.formUnion(reservations)
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
    public func removeCascading(_ objectID: ObjectID) -> Set<ObjectID> {
        precondition(state == .transient)
        precondition(contains(objectID), "Unknown object ID \(objectID) in frame \(self.id)")
        
        var removed: Set<ObjectID> = Set()
        var scheduled: Set<ObjectID> = [objectID]
        
        while !scheduled.isEmpty {
            let garbageID = scheduled.removeFirst()
            let garbage = _snapshots[garbageID]!
            _remove(snapshotID: garbage.snapshotID, objectID: garbage.objectID)
            
            if garbage.isOriginal {
                // FIXME: [WIP] [IMPORTANT] Implement this
                fatalError("Should add removed ")
                // _removedObjects[garbageID] = garbage
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
            for dependant in snapshots where !removed.contains(dependant.objectID) {
                switch dependant.structure {
                case let .edge(origin, target):
                    if origin == garbageID || target == garbageID {
                        scheduled.insert(dependant.objectID)
                    }
                case .orderedSet(let owner, var items):
                    if owner == garbageID {
                        scheduled.insert(dependant.objectID)
                    }
                    else if items.contains(garbageID) {
                        let update = mutate(dependant.objectID)
                        items.remove(garbageID)
                        update.structure = .orderedSet(owner, items)
                    }
                case .unstructured:
                    break
                case .node:
                    break
                }
            }
        }
        return removed
    }
    @inlinable
    func _remove(snapshotID: ObjectID, objectID: ObjectID) {
        _snapshots.remove(objectID)
        _snapshotIDs.remove(snapshotID)
        _removedObjects.insert(objectID)
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
    public func mutate(_ id: ObjectID) -> TransientObject {
        precondition(state == .transient)
        
        guard let current = _snapshots[id] else {
            preconditionFailure("No object with ID \(id) in frame ID \(self.id)")
        }
        switch current.content {
        case .mutable(_, let snapshot):
            return snapshot
        case .stable(_ , let original):
            let derivedSnapshotID = design.identityManager.createAndReserve(type: .snapshot)
            let derived = TransientObject(original: original, snapshotID: derivedSnapshotID)
            let box = _TransientSnapshotBox(derived, isNew: false)
            _snapshots.replace(box)
            _reservations.insert(derivedSnapshotID)
            _snapshotIDs.remove(original.snapshotID)
            _snapshotIDs.insert(derivedSnapshotID)
            return derived
        }
    }
    
    /// Checks whether the object is marked as mutable.
    ///
    /// - SeeAlso: ``mutate(_:)``
    ///
    public func isMutable(_ id: ObjectID) -> Bool {
        guard let cell = _snapshots[id] else {
            preconditionFailure("Frame \(self.id) has no object \(id)")
        }
        return cell.isMutable
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
    /// - SeeAlso: ``ObjectSnapshotProtocol/children``, ``ObjectSnapshotProtocol/parent``,
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
    /// - SeeAlso: ``ObjectSnapshotProtocol/children``, ``ObjectSnapshotProtocol/parent``,
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
    /// - SeeAlso: ``ObjectSnapshotProtocol/children``, ``ObjectSnapshotProtocol/parent``,
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
    /// - SeeAlso: ``ObjectSnapshotProtocol/children``, ``ObjectSnapshotProtocol/parent``,
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
        _snapshots.compactMap {
            $0.structure.type == .edge ? $0.id : nil
        }
    }

    public var nodeIDs: [ObjectID] {
        _snapshots.compactMap {
            $0.structure.type == .node ? $0.id : nil
        }
    }
}


extension TransientFrame {
    func setOrder(ids: [ObjectID], start: Int = 0, stride: Int = 1) {
        
    }
}
