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

public class MutableFrame: FrameBase {
    public var snapshots: [ObjectSnapshot] {
        return self.objects.values.map { $0.snapshot }
    }
    
    public func contains(_ id: ObjectID) -> Bool {
        return self.objects[id] != nil
    }
    
    public func object(_ id: ObjectID) -> ObjectSnapshot? {
        return self.objects[id].map { $0.snapshot }
    }
    
    unowned let memory: ObjectMemory
    public let id: FrameID
    // TODO: Remove state
    var state: VersionState = .unstable
    
    var snapshotIDs: Set<SnapshotID>
    var objects: [ObjectID:SnapshotReference]
    var removedObjects: Set<ObjectID> = Set()

    
    var derivedObjects: [ObjectSnapshot] {
        return objects.values.filter {
            $0.owned
        }
        .map {
            $0.snapshot
        }
    }
    var hasChanges: Bool {
        (!removedObjects.isEmpty || !derivedObjects.isEmpty)
    }
    
    init(memory: ObjectMemory,
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
    
    func insert(_ snapshot: ObjectSnapshot, owned: Bool = false) {
        precondition(state.isMutable)
        precondition(objects[snapshot.id] == nil)
        precondition(!snapshotIDs.contains(snapshot.snapshotID))
        // Make sure we do not own immutable objects.
        precondition((owned && snapshot.state.isMutable)
                    || (!owned && !snapshot.state.isMutable))
        
        let ref = SnapshotReference(snapshot: snapshot,
                                    owned: owned)

        objects[snapshot.id] = ref
        snapshotIDs.insert(snapshot.snapshotID)
    }

    /// Derive a version snapshot of an object and insert it into the frame.
    ///
    /// - Parameters:
    ///     - snapshot: Snapshot to be derived and inserted
    ///     - id: Optional Object ID of the derived object.
    ///
    /// This method can be used to create new objects in the frame from
    /// prototype snapshots.
    ///
    func insertDerived(_ original: ObjectSnapshot,
                       id: ObjectID? = nil) -> ObjectID {
        // TODO: This should be used in the mutable unbound graph (see .py)
        let actualObjectID = id ?? self.memory.identityGenerator.next()
        let snapshotID = self.memory.identityGenerator.next()
        let derived = original.derive(snapshotID: snapshotID, objectID: actualObjectID)
        self.insert(derived, owned: true)
        return actualObjectID
    }

    public func create(_ objectType: ObjectType? = nil,
                       components: [any Component] = []) -> ObjectID {
        precondition(state.isMutable)
        
        let objectID = memory.identityGenerator.next()
        let snapshotID = memory.identityGenerator.next()
        let object = ObjectSnapshot(id: objectID,
                                    snapshotID: snapshotID,
                                    type: objectType,
                                    components: components)
        let ref = SnapshotReference(snapshot: object,
                                       owned: true)
        objects[objectID] = ref
        snapshotIDs.insert(snapshotID)
        return objectID
    }
    
    // TODO: func insertDerived(...)
    @discardableResult
    public func removeCascading(_ id: ObjectID) -> Set<ObjectID> {
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
        objects[snapshot.id] = nil
        snapshotIDs.remove(snapshot.snapshotID)
        removedObjects.insert(id)
    }
    

    public func freeze() {
        /// Freeze the frame so it can no longer be mutated.
        ///
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
    public func mutableObject(_ id: ObjectID) -> ObjectSnapshot {
        precondition(state.isMutable, "Trying to modify a frozen frame")

        guard let ref = self.objects[id] else {
            fatalError("No object \(id)")
        }
        if ref.owned {
            return ref.snapshot
        }
        else {
            let newSnapshotID = self.memory.identityGenerator.next()
            let derived = ref.snapshot.derive(snapshotID: newSnapshotID)
            let ref = SnapshotReference(snapshot: derived, owned: true)
            self.objects[id] = ref
            self.snapshotIDs.remove(ref.snapshot.snapshotID)
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
