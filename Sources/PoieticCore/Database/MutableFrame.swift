//
//  File.swift
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
/// - Add objects to the frame using ``MutableFrame/create(_:components:)``
///    or ``MutableFrame/insertDerived(_:id:)``.
/// - Mutate existing objects in the frame using
///   ``MutableFrame/mutableObject(_:)``.
///
/// Completed change set is expected to be accepted to the memory using
/// ``ObjectMemory/accept(_:appendHistory:)``.
///
public class MutableFrame: FrameBase {
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
    public func object(_ id: ObjectID) -> ObjectSnapshot? {
        return self.objects[id].map { $0.snapshot }
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
    var state: VersionState = .unstable
    
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
    
    /// Low-level insert of an object snapshot to a frame.
    ///
    /// Caller must be sure that the snapshot is not owned by anyone.
    ///
    func insert(_ snapshot: ObjectSnapshot, owned: Bool = false) {
        precondition(state.isMutable,
                     "Trying to modify a frame that is not mutable")
        precondition(snapshot.state != .unstable,
                     "Trying to insert an unstable object")
        precondition(objects[snapshot.id] == nil,
                     "Trying to insert an object with object ID \(snapshot.id) that already exists in frame \(id)")
        precondition(!snapshotIDs.contains(snapshot.snapshotID),
                     "Trying to insert an object with snapshot ID \(snapshot.snapshotID) that already exists in frame \(id)")
        // FIXME: Test whether the object is owned by the memory
        
        // Make sure we do not own immutable objects.
        precondition((owned && snapshot.state.isMutable)
                    || (!owned && !snapshot.state.isMutable))
        
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
    /// - SeeAlso: ``ObjectSnapshot/init(id:snapshotID:type:components:)``
    ///
    public func create(_ type: ObjectType,
                       components: [any Component] = []) -> ObjectID {
        precondition(state.isMutable)
        
        let snapshot = memory.createSnapshot(type, components: components)
        let ref = SnapshotReference(snapshot: snapshot,
                                       owned: true)
        objects[snapshot.id] = ref
        snapshotIDs.insert(snapshot.snapshotID)
        return snapshot.id
    }
    
    /// Remove an object from the frame and all its dependants.
    ///
    /// The method removes the object with given object ID. Then traverses
    /// and removes all the objects that depend on the removed object.
    ///
    /// - Returns: A list of objects removed from the frame except the object
    ///   asked to be removed.
    ///
    /// - Precondition: The frame must contain object with given ID.
    /// - Precondition: The frame is not frozen. See ``freeze()``.
    ///
    @discardableResult
    public func removeCascading(_ id: ObjectID) -> Set<ObjectID> {
        // TODO: func insertDerived(...)
        precondition(state.isMutable)
        guard let snapshot = objects[id] else {
            fatalError("Unknown object ID \(id) in frame \(self.id)")
        }
        
        var removed: Set<ObjectID> = Set()
        
        for ref in objects.values {
            if ref.snapshot.structuralDependencies.contains(id) {
                _remove(ref.snapshot)
                removed.insert(ref.snapshot.id)
            }
        }

        _remove(snapshot.snapshot)
        
        return removed
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
        precondition(state.isMutable, "Trying to modify a frozen frame")

        guard let originalRef = self.objects[id] else {
            fatalError("No object with ID \(id) in frame ID \(self.id)")
        }
        if originalRef.owned {
            return originalRef.snapshot
        }
        else {
            let newSnapshotID = memory.allocateID()
            let derived = originalRef.snapshot.derive(snapshotID: newSnapshotID)
            let ref = SnapshotReference(snapshot: derived, owned: true)
            self.objects[id] = ref
            self.snapshotIDs.remove(originalRef.snapshot.snapshotID)
            self.snapshotIDs.insert(newSnapshotID)
            
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
}
