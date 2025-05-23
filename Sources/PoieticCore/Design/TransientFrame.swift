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

/// Reference counted storage of object snapshots.
///
/// Features of the snapshot storage:
/// - Reference counting with ``insertOrRetain(_:)`` and ``release(_:)``.
/// - Fast lookup by snapshot ID ``snapshot(_:)`` and ``contains(_:)``.
///
/// Generally the snapshot storage tries to preserve relative order of objects after insertion.
/// Exception is insertion after object removal, when an object might be inserted in between
/// existing objects, disrupting local order of the neighbours. Note that the general order of
/// insertion is not preserved.
///
class TransientSnapshotStorage {
    enum Cell {
        case stable(isOriginal: Bool, object: DesignObject)
        case mutable(MutableObject)
        
        var isOriginal: Bool {
            switch self {
            case .stable(let flag, _): flag
            case .mutable(_): false
            }
        }
        
        var isMutable: Bool {
            switch self {
            case .stable(_, _): false
            case .mutable(_): true
            }
        }
        
        var id: ObjectID {
            switch self {
            case let .stable(_, object): object.id
            case let .mutable(object): object.id
            }
        }

        var snapshotID: SnapshotID {
            switch self {
            case let .stable(_, object): object.snapshotID
            case let .mutable(object): object.snapshotID
            }
        }
        
        var parent: ObjectID? {
            switch self {
            case let .stable(_, object): object.parent
            case let .mutable(object): object.parent
            }
        }
        
        var children: ChildrenSet {
            switch self {
            case let .stable(_, object): object.children
            case let .mutable(object): object.children
            }
        }
        
        var structure: Structure {
            switch self {
            case let .stable(_,object): object.structure
            case let .mutable(object): object.structure
            }
        }
    }

    @usableFromInline
    var _snapshots: GenerationalArray<Cell>

    @usableFromInline
    var _lookup: [ObjectID:GenerationalArray<Cell>.Index]
    
    var _snapshotIDs: Set<ObjectID>
    
    /// Create an empty snapshot storage.
    ///
    init() {
        self._snapshots = []
        self._lookup = [:]
        self._snapshotIDs = Set()
    }
    
    /// Get a list of contained snapshots.
    ///
    var cells: some Collection<Cell> {
        return _snapshots
    }
    
    public var originals: [ObjectID] {
        _snapshots.compactMap {
            switch $0 {
            case .mutable(_): nil
            case let .stable(isOriginal: flag, object: object):
                if flag { object.id } else { nil }
            }
        }
    }
    
    var changed: [ObjectID] {
        _snapshots.compactMap {
            switch $0 {
            case let .mutable(object):
                if object.original == nil || object.hasChanges {
                    object.id
                }
                else {
                    nil
                }
            case let .stable(isOriginal: original, object: object):
                if original { nil } else { object.id }
            }
        }
    }

    var mutableObjects: [MutableObject] {
        _snapshots.compactMap {
            switch $0 {
            case let .mutable(object): object
            case .stable(_, _): nil
            }
        }
    }

    
    /// Returns `true` if the storage contains a snapshot with given ID.
    ///
    func contains(_ id: ObjectID) -> Bool {
        _lookup[id] != nil
    }
    public func contains(snapshotID: ObjectID) -> Bool {
        _snapshotIDs.contains(snapshotID)
    }

    /// Get a snapshot by snapshot ID, if it exists.
    ///
    @inlinable
    func cell(_ id: ObjectID) -> Cell? {
        guard let index = _lookup[id] else {
            return nil
        }
        return _snapshots[index]
    }
    
    @inlinable
    subscript(_ id: ObjectID) -> Cell? {
        return cell(id)
    }

    /// Inserts a snapshot into the store, if it does not already exist or increases reference
    /// count of a snapshot.
    ///
    /// - Precondition: If the store already contains snapshot with given ID it must be the same
    ///   snapshot.
    public func append(_ snapshot: DesignObject, isOriginal: Bool) {
        precondition(_lookup[snapshot.id] == nil)
        precondition(!_snapshotIDs.contains(snapshot.snapshotID))
        let index = _snapshots.append(Cell.stable(isOriginal: isOriginal, object: snapshot))
        _lookup[snapshot.id] = index
        _snapshotIDs.insert(snapshot.snapshotID)
    }

    func append(_ snapshot: MutableObject) {
        precondition(_lookup[snapshot.id] == nil)
        precondition(!_snapshotIDs.contains(snapshot.snapshotID))
        let index = _snapshots.append(Cell.mutable(snapshot))
        _lookup[snapshot.id] = index
        _snapshotIDs.insert(snapshot.snapshotID)
    }
    
    func replace(_ newSnapshot: MutableObject) {
        guard let index = _lookup[newSnapshot.id] else {
            preconditionFailure("No object with id '\(newSnapshot.id)' to be replaced")
        }
        let existing = _snapshots[index]
        _snapshotIDs.remove(existing.snapshotID)
        _snapshots[index] = Cell.mutable(newSnapshot)
        _snapshotIDs.insert(newSnapshot.snapshotID)
    }


    /// Reduce reference count of an object. If the reference count reaches zero, the object is
    /// removed from the store.
    ///
    func remove(_ id: ObjectID) {
        guard let index = _lookup[id] else {
            preconditionFailure("Missing snapshot \(id)")
        }
        let snapshotID = _snapshots[index].snapshotID
        _snapshots.remove(at: index)
        _lookup[id] = nil
        _snapshotIDs.remove(snapshotID)
    }
}

extension TransientSnapshotStorage: Collection {
    public typealias Index = GenerationalArray<Cell>.Index
    public typealias Element = Cell
    
    public var startIndex: Index {
        return _snapshots.startIndex
    }
    
    public var endIndex: Index {
        return _snapshots.endIndex
    }
    
    public func index(after i: Index) -> Index {
        return _snapshots.index(after: i)
    }
    
    public subscript(position: Index) -> Cell {
        return _snapshots[position]
    }
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
    
    // FIXME: Order is not preserved, use SnapshotStorage or something similar
    var _snapshots: TransientSnapshotStorage
    var _removedObjects: Set<ObjectID>
    var _reservations: Set<ObjectID>
    public var removedObjects: [ObjectID] { Array(_removedObjects) }
    
    public var mutableObjects: [MutableObject] {
        _snapshots.mutableObjects
    }
    
    /// List of snapshots in the frame.
    ///
    /// - Note: The order of the snapshots is arbitrary. Do not rely on it.
    ///
    public var snapshots: [DesignObject] {
        // FIXME: [WIP] Review necessity of this.
        _snapshots.map {
            switch $0 {
            case let .mutable(object): DesignObject(body: object._body, components: object.components)
            case let .stable(_, object): object
            }

        }
    }
    
    /// Returns `true` if the frame contains an object with given object ID.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        _snapshots[id] != nil
    }
    public func contains(snapshotID: ObjectID) -> Bool {
        return _snapshots.contains(snapshotID: snapshotID)
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
        // FIXME: [WIP] Review necessity of this.
        guard let cell = _snapshots[id] else {
            preconditionFailure("Unknown object \(id)")
        }
        switch cell {
        case let .mutable(object): return DesignObject(body: object._body, components: object.components)
        case let .stable(_, object): return object
        }
    }
    
    /// Get an object version of object with identity `id`.
    ///
    public subscript(id: ObjectID) -> DesignObject {
        get { object(id) }
    }
    
    /// Flag whether the mutable frame has any changes.
    public var hasChanges: Bool {
        return !(removedObjects.isEmpty && _snapshots.changed.isEmpty)
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
    /// - Precondition: Snapshots must have structural integrity.
    ///
    public init(design: Design,
                id: FrameID,
                snapshots: [DesignObject]? = nil) {
        // TODO: Either validate after init or rename argument snapshots: to unsafeSnapshots:
        self.design = design
        self.id = id
        self._snapshots = TransientSnapshotStorage()
        self._removedObjects = Set()
        self._reservations = []
        
        if let snapshots {
            for snapshot in snapshots {
                _snapshots.append(snapshot, isOriginal: false)
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
        design.identityManager.useReservations(Array(_reservations))
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
        design.identityManager.releaseReservations(Array(_reservations))
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
        // IMPORTANT: Sync the logic (especially preconditions) as in RawDesignLoader.create(...)
        // TODO: Consider moving this to Design (as well as its RawDesignLoader counterpart)
        // FIXME: [WIP] Consider throwing an exception instead of having runtime errors
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
        if let id {
            let success = design.identityManager.reserveIfNeeded(id, type: .object)
            precondition(success, "Type mismatch for ID \(id)")
            precondition(!self.contains(id), "Duplicate ID \(id)")
            actualID = id
        }
        else {
            actualID = design.identityManager.createAndReserve(type: .object)
        }
        _reservations.insert(actualID)

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
        case .orderedSet:
            guard let structure else {
                fatalError("Structural component of type `orderedSet` is required to be provided for type \(type.name)")
            }
            precondition(structure.type == .orderedSet,
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
        
        _snapshots.append(snapshot)
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
    public func insert(_ snapshot: DesignObject) {
        // TODO: Make insert() function throwing (StructuralIntegrityError)
        // Check for referential integrity
        do {
            try validateStructure(snapshot)
        }
        catch {
            preconditionFailure("Structural integrity error")
        }
        
        unsafeInsert(snapshot)
    }
    public func validateStructure(_ snapshot: DesignObject) throws (StructuralIntegrityError) {
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
    public func unsafeInsert(_ snapshot: DesignObject) {
        // FIXME: [WIP] [IMPORTANT] Check for snapshot ID existence
        precondition(state == .transient)
        precondition(_snapshots[snapshot.id] == nil,
                     "Inserting duplicate object ID \(snapshot.id) to frame \(id)")
        precondition(_snapshots.allSatisfy { $0.snapshotID != snapshot.snapshotID },
                     "Inserting duplicate snapshot ID \(snapshot.id) to frame \(id)")
        
        _snapshots.append(snapshot, isOriginal: false)
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
        precondition(contains(id), "Unknown object ID \(id) in frame \(self.id)")
        
        var removed: Set<ObjectID> = Set()
        var scheduled: Set<ObjectID> = [id]
        
        while !scheduled.isEmpty {
            let garbageID = scheduled.removeFirst()
            // FIXME: We should do it without asStable()
            let garbage = _snapshots[garbageID]!
            _snapshots.remove(garbageID)
            _removedObjects.insert(garbageID)
            
            if garbage.isOriginal {
                // FIXME: [WIP] !!!IMPORTANT NOT IMPLEMENTED!!!
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
            for dependant in snapshots where !removed.contains(dependant.id) {
                switch dependant.structure {
                case let .edge(origin, target):
                    if origin == garbageID || target == garbageID {
                        scheduled.insert(dependant.id)
                    }
                case .orderedSet(let owner, var items):
                    if owner == garbageID {
                        scheduled.insert(dependant.id)
                    }
                    else if items.contains(garbageID) {
                        let update = mutate(dependant.id)
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
        
        guard let current = _snapshots[id] else {
            preconditionFailure("No object with ID \(id) in frame ID \(self.id)")
        }
        switch current {
        case .mutable(let snapshot):
            return snapshot
        case .stable(_ , let original):
            let derivedSnapshotID: SnapshotID = design.identityManager.createAndReserve(type: .snapshot)
            let derived = MutableObject(original: original, snapshotID: derivedSnapshotID)
            _snapshots.replace(derived)
            _reservations.insert(derivedSnapshotID)
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
