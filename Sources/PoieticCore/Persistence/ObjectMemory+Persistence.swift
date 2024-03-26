//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 21/10/2023.
//

import Foundation
extension ObjectSnapshot {
    /// Get a foreign record with all object's attributes
    public func asForeignObject() -> ForeignObject {
        return ForeignObject(
            info: infoAsForeignRecord(),
            attributes: ForeignRecord(attributes)
        )
    }
    public func infoAsForeignRecord() -> ForeignRecord {
        var dict: [String:Variant] = [:]
        dict["id"] = Variant(Int(id))
        dict["snapshot_id"] = Variant(Int(snapshotID))
        dict["type"] = Variant(type.name)
        dict["structure"] = Variant(structure.type.rawValue)
        if case let .edge(origin, target) = structure {
            dict["origin"] = Variant(Int(origin))
            dict["target"] = Variant(Int(target))
        }
        if let parent {
            dict["parent"] = Variant(Int(parent))
        }
        return ForeignRecord(dict)
    }
    
    // This is not to conform to "encodable" but to satisfy encoding of
    // ForeignObject. We can not assure symmetrical encoding/decoding of object
    // snapshots because of custom runtime components.
    //
    enum ForeignObjectCodingKeys: String, CodingKey {
        case id
        case snapshotID
        case type
        case structure
        case origin
        case target
        case parent
        case attributes
    }

    
    /// Create a foreign record from the object snapshot.
    ///
    /// The foreign record does not include
    ///
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
        // Store content:
        // - all snapshots (object info, attributes)
        // - frames (frame ID, list of snapshots)
        //
        var outSnapshots: [ForeignObject] = []
        var outFrames: [ForeignRecord] = []
        
        // 1. Collect snapshots and components
        // ----------------------------------------------------------------
        //
        for snapshot in validatedSnapshots {
            let record = snapshot.asForeignObject()
            outSnapshots.append(record)
        }
        try store.replaceAllObjects(outSnapshots)
        
        // 2. Collect components
        // ----------------------------------------------------------------
        //
        // Nothing to do any more (or ... nothing to do yet)
        
        // 3. Frames
        // ----------------------------------------------------------------
        //
        for frame in self._stableFrames.values {
            let snapshotIDs: [Int] = frame.snapshots.map { Int($0.snapshotID) }
            
            let record = ForeignRecord(
                [
                    "id": Variant(Int(frame.id)),
                    "snapshots": Variant(snapshotIDs),
                ]
            )
            outFrames.append(record)
        }
        try store.replaceAll(in: MakeshiftMemoryStore.FramesCollectionName,
                             records: outFrames)

        // 4. Memory state (undo, redo, current frame)
        // ----------------------------------------------------------------
        
        let undoables = undoableFrames.map { Int($0) }
        let redoables = redoableFrames.map { Int($0) }

        var state: ForeignRecord = ForeignRecord([
            "undo": Variant(undoables),
            "redo": Variant(redoables)
        ])
        if let id = currentFrameID {
            state["currentFrameID"] = Variant(Int(id))

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
        
        for record in try store.fetchAllObjects() {
            let snapshot = try createSnapshot(record)
            guard snapshots[snapshot.snapshotID] == nil else {
                // TODO: Collect error and continue
                throw MemoryStoreError.duplicateSnapshot(snapshot.snapshotID)
            }
            snapshots[snapshot.snapshotID] = snapshot
        }

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
            let frameID = try idValue.IDValue()

            let ids: [ObjectID]
            
            if let idsValue = record["snapshots"] {
                ids = try idsValue.IDArray()
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

        if let items = try info["undo"]?.IDArray() {
            guard items.allSatisfy( { containsFrame($0) } ) else {
                // let offensive = undoFrames.filter { !containsFrame($0) }
                throw MemoryStoreError.invalidReferences("frame", "undo frame list")
            }
            self.undoableFrames = items

        }

        if let items = try info["redo"]?.IDArray() {
            guard items.allSatisfy( { containsFrame($0) } ) else {
                // let offensive = undoFrames.filter { !containsFrame($0) }
                throw MemoryStoreError.invalidReferences("frame", "redo frame list")
            }
            self.redoableFrames = items

        }

        if let currentID = try info["currentFrameID"]?.IDValue() {
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
