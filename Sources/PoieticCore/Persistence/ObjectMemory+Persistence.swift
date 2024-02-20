//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 21/10/2023.
//

import Foundation
extension ObjectSnapshot {
    /// Create a foreign record from the object snapshot.
    ///
    /// The foreign record does not include
    ///
    public func foreignRecord() -> ForeignRecord {
        var dict: [String:ForeignValue] = self.attributes
        dict["id"] = ForeignValue(id)
        dict["snapshot_id"] = ForeignValue(snapshotID)
        dict["type"] = ForeignValue(type.name)
        dict["structure"] = ForeignValue(structure.type.rawValue)
        if case let .edge(origin, target) = structure {
            dict["origin"] = ForeignValue(origin)
            dict["target"] = ForeignValue(target)
        }
        if let parent {
            dict["parent"] = ForeignValue(parent)
        }
        return ForeignRecord(dict)
    }
}

extension ObjectMemory {
    /// Saves the contents of the memory to given URL.
    ///
    /// - Note: Only the same tool can read the archive created using
    ///         this method.
    /// - Note: The archive format will very likely change.
    ///
    public func saveAll(to url: URL) throws {
        let store = try MakeshiftMemoryStore(url: url)
        try self.writeAll(store: store)
    }
    
    

    /// Removes everything from the memory and loads the contents from the
    /// given URL.
    ///
    /// - Note: Can read only archives written by the same tool that
    ///         wrote the archive.
    ///
    public func restoreAll(from url: URL) throws {
        let store = try MakeshiftMemoryStore(url: url)
        try self.restoreAll(store: store)
    }
    
    public func writeAll(store: MakeshiftMemoryStore) throws {
        var outSnapshots: [ForeignRecord] = []
        var outFrames: [ForeignRecord] = []
        
        // 1. Collect snapshots and components
        // ----------------------------------------------------------------
        //
        for snapshot in validatedSnapshots {
            let record = snapshot.foreignRecord()
            outSnapshots.append(record)
        }
        try store.replaceAll(in: MakeshiftMemoryStore.SnapshotsCollectionName,
                             records: outSnapshots)
        
        // 2. Collect components
        // ----------------------------------------------------------------
        //
        // Nothing to do any more (or ... nothing to do yet)
        
        // 3. Frames
        // ----------------------------------------------------------------
        //
        for frame in self._stableFrames.values {
            let snapshotIDs: [ObjectID] = frame.snapshots.map { $0.snapshotID }
            let record = ForeignRecord(
                [
                    "id": ForeignValue(frame.id),
                    "snapshots": ForeignValue(ids: snapshotIDs),
                ]
            )
            outFrames.append(record)
        }
        try store.replaceAll(in: MakeshiftMemoryStore.FramesCollectionName,
                             records: outFrames)

        // 4. Memory state (undo, redo, current frame)
        // ----------------------------------------------------------------
        
        var state: ForeignRecord = ForeignRecord([
            "undo": ForeignValue(ids: undoableFrames),
            "redo": ForeignValue(ids: redoableFrames),
        ])
        if let id = currentFrameID {
            state["currentFrameID"] = ForeignValue(id)

        }
        try store.replaceAll(in: MakeshiftMemoryStore.MemoryStateCollectionName,
                             records: [state])
        // Finally: save the store
        // ----------------------------------------------------------------
        try store.save()
    }

    /// Removes everything from the memory and loads the contents from the
    /// given memory store.
    ///
    /// - Note: Can read only archives written by the same tool that
    ///         wrote the archive.
    ///
    public func restoreAll(store: MakeshiftMemoryStore) throws {
        // TODO: Collect multiple issues
        try store.load()
        
        // 0. Remove everything
        // ----------------------------------------------------------------

        removeAll()
        
        // 1. Read Snapshots
        // ----------------------------------------------------------------
        var snapshots: [SnapshotID: ObjectSnapshot] = [:]
        
        for record in try store.fetchAll(MakeshiftMemoryStore.SnapshotsCollectionName) {
            let snapshot = try createSnapshot(record)
            guard snapshots[snapshot.snapshotID] == nil else {
                // TODO: Collect error and continue
                throw MemoryStoreError.duplicateSnapshot(snapshot.snapshotID)
            }
            snapshots[snapshot.snapshotID] = snapshot
        }

//        // 2. Read components
//        // ----------------------------------------------------------------
//
//        for componentName in store.componentNames {
//            guard let componentType = metamodel.inspectableComponent(name: componentName) else {
//                // TODO: Collect error and continue
//                throw MemoryStoreError.unknownComponentType(componentName)
//            }
//            let collectionName = componentName + MakeshiftMemoryStore.ComponentCollectionSuffix
//            let records = try store.fetchAll(collectionName)
//            for record in records {
//                guard let snapshotIDValue = record["snapshot_id"] else {
//                    throw MemoryStoreError.brokenIntegrity("Missing snapshot_id in component \(componentName)")
//                }
//                let snapshotID = try snapshotIDValue.idValue()
//                guard let snapshot = snapshots[snapshotID] else {
//                    throw MemoryStoreError.invalidReference(snapshotID, "snapshot", "component \(componentName)")
//                }
//                let component = try componentType.init(record: record)
//                snapshot.components.set(component)
//            }
//        }
       
        for snapshot in snapshots.values {
            snapshot.promote(.validated)
        }
        
        // 3. Read frames
        // ----------------------------------------------------------------

        let frameRecords = try store.fetchAll(MakeshiftMemoryStore.FramesCollectionName)
        
        for record in frameRecords {
            guard let idValue = record["id"] else {
                throw MemoryStoreError.missingReference("frame", "frames collection")
            }
            let frameID = try idValue.idValue()

            let ids: [ObjectID]
            
            if let idsValue = record["snapshots"] {
                ids = try idsValue.idArray()
            }
            else {
                ids = []
            }

            let frame = createFrame(id: frameID)
            for id in ids {
                guard let snapshot = snapshots[id] else {
                    throw MemoryStoreError.invalidReference(id, "snapshot", "frame \(frameID)")
                }
                // Do not check for referential integrity yet
                frame.unsafeInsert(snapshot, owned: false)
            }
            // We accept the frame making sure that constraints are met.
            // FIXME: We need to mark a frame as "OK" in our (non-corrupted) database, so we do not have to accept it.
            try accept(frame)
        }

        // 4. Memory state (undo, redo, current frame)
        // ----------------------------------------------------------------
        
        let infoCollection = try store.fetchAll(MakeshiftMemoryStore.MemoryStateCollectionName)
        
        guard let info = infoCollection.first else {
            // TODO: This should be a warning. We can recover
            throw MemoryStoreError.missingOrMalformedStateInfo
        }

        let undoFrames = try info["undo"]?.idArray() ?? []
        let redoFrames = try info["redo"]?.idArray() ?? []

        guard undoFrames.allSatisfy( { containsFrame($0) } ) else {
            // let offensive = undoFrames.filter { !containsFrame($0) }
            throw MemoryStoreError.invalidReferences("frame", "undo frame list")
        }

        guard redoFrames.allSatisfy( { containsFrame($0) } ) else {
            // let offensive = redoFrames.filter { !containsFrame($0) }
            throw MemoryStoreError.invalidReferences("frame", "redo frame list")
        }

        self.undoableFrames = undoFrames
        self.redoableFrames = redoFrames
        
        if let currentID = try info["currentFrameID"]?.idValue() {
            guard containsFrame(currentID) else {
                throw MemoryStoreError.invalidReference(currentID, "frame", "current frame reference")
            }
            self.currentFrameID = currentID
        }

        // Consistency check: currentFrameID must be set when there is history.
        if currentFrameID == nil
            && (!undoableFrames.isEmpty || !redoableFrames.isEmpty) {
            throw MemoryStoreError.brokenIntegrity("Current frame ID is not set while undo/redo history is not-empty")
        }
    }
}
