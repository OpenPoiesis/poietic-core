//
//  File.swift
//
//
//  Created by Stefan Urbanek on 23/06/2023.
//

import Foundation

enum ForeignInterfaceError: Error {
    case unsupportedVersion(String)
    case unknownStructuralType(String)
    case malformedComponents
    case malformedMainRecord
    
    
    case typeMismatchError(ForeignValue, AtomType)
}

// FIXME: [PROTOTYPE] This is a temporary solution. See note below.
/*
    NOTE:
 
    The design of writing/reading from a store was not finished
    at the time of writing and it got too complicated. I decided to
    create a temporary solution using Codable.

    The solution using Codable is not appropriate, because we want the format
    to be readable and, to an extent, modify-able by external tools.

    The persistence is a problem MUST be resolved quite seriously.
 */

struct ArchiveInfo: Codable {
    var formatVersion: String = "0.0.1"
    var currentFrameID: FrameID?
}


//class Frameset: Codable {
//    var frames: [FrameID]
//}
//

// NOTE: Use MemoryArchive_*_*_* pattern, then use CurrentMemoryArchive alias
private struct MemoryArchive: Codable {
    fileprivate var info: ArchiveInfo = ArchiveInfo()
    fileprivate var framesets: [String: [FrameID]] = [:]
    fileprivate var frames: [FrameID: [SnapshotID]] = [:]
    fileprivate var snapshots: [ExtendedForeignRecord] = []
    
//    enum CodingKeys: CodingKey, String {
//        case info = "info"
//    }
    
    func _encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(info, forKey: .info)
        try container.encode(framesets, forKey: .framesets)
        
        var rekeyed: [String: [SnapshotID]] = [:]
        for (key, value) in frames {
            rekeyed[String(key)] = value
        }
        
        try container.encode(rekeyed, forKey: .frames)
        try container.encode(snapshots, forKey: .snapshots)
    }
}

extension ObjectMemory {
    func createSnapshot(record: ExtendedForeignRecord) throws -> ObjectSnapshot {
        // TODO: Check for existence and register with list of all snapshots.
        // TODO: This should include the snapshot into the list of snapshots.
        // TODO: Handle wrong IDs.
        let id: ObjectID = try record.main.IDValue(for: "object_id")
        let snapshotID: SnapshotID = try record.main.IDValue(for: "snapshot_id")

        let type: ObjectType
        
        let typeName = try record.main.stringValue(for: "type")
        if let objectType = metamodel.objectType(name: typeName) {
            type = objectType
        }
        else {
            fatalError("Unknown object type: \(typeName)")
        }

        var components: [any Component] = []
        
        for (name, compRecord) in record.components {
            guard let type: Component.Type = metamodel.componentType(name: name) else {
                fatalError("No registered component with name: \(name)")
            }
            let component = try type.init(record: compRecord)
            components.append(component)
        }

        let references: [ObjectID]
        
        switch type.structuralType {
        case .node, .unstructured:
            references = []
        case .edge:
            let origin: ObjectID = try record.main.IDValue(for: "origin")
            let target: ObjectID = try record.main.IDValue(for: "target")
            references = [origin, target]
        }
        let snapshot = createSnapshot(type,
                                      id: id,
                                      snapshotID: snapshotID,
                                      components: components,
                                      structuralReferences: references)
        snapshot.freeze()
        return snapshot
    }

    private func createArchive() -> MemoryArchive {
        // TODO: This is preliminary implementation, which is not fully normalized
        // Collections to be written
        //
        var archive = MemoryArchive()
        
        archive.info.currentFrameID = currentFrameID
        
        // 1. Write Snapshots
        // ----------------------------------------------------------------
        
        for snapshot in snapshots {
            let main = snapshot.foreignRecord()
            var components: [String:ForeignRecord] = [:]

            for component in snapshot.components {
                let componentRecord = component.foreignRecord()
                components[component.componentName] = componentRecord
            }
            
            let extended = ExtendedForeignRecord(main: main,
                                                 components: components)
            archive.snapshots.append(extended)
        }

        // 2. Write Stable Frames
        // ----------------------------------------------------------------
        // Unstable frames should not be persisted.
        
        for frame in frames {
            let ids: [SnapshotID] = frame.snapshots.map { $0.snapshotID }
            archive.frames[frame.id] = ids
        }
        // 3. Write Framesets
        // ----------------------------------------------------------------
        // We have only one frameset at the moment - undo history
        // TODO: What about current frame?
        archive.framesets["undo"] = undoableFrames
        archive.framesets["redo"] = redoableFrames

        return archive
    }

    /// Saves the contents of the memory to given URL.
    ///
    /// - Note: Only the same tool can read the archive created using
    ///         this method.
    /// - Note: The archive format will very likely change.
    ///
    public func saveAll(to url: URL) throws {
        let archive = createArchive()
        let encoder = JSONEncoder()
        
        let data = try encoder.encode(archive)

        try data.write(to: url)
    }
    
    

    /// Removes everything from the memory and loads the contents from the
    /// given URL.
    ///
    /// - Note: Can read only archives written by the same tool that
    ///         wrote the archive.
    ///
    public func restoreAll(from url: URL) throws {
        /*
            TODO: Raise the following errors:
            - file not found
            - corrupted JSON
            - snapshot creation error:
                - unknown object type
                - invalid structural type value type
                - missing origin (edge)
                - missing target (edge)
                - unable to create a component
            - duplicate snapshot ID
            - frame references an unknown snapshot
            - frame violates constraints
            - frameset has unknown frame ID
         
         */
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: url)
        let archive = try decoder.decode(MemoryArchive.self, from: data)

        // 0. Remove everything
        // ----------------------------------------------------------------

        removeAll()
        
        // 1. Read Snapshots
        // ----------------------------------------------------------------

        var snapshots: [SnapshotID: ObjectSnapshot] = [:]
        
        for record in archive.snapshots {
            let snapshot = try createSnapshot(record: record)
            guard snapshots[snapshot.snapshotID] == nil else {
                fatalError("Duplicate snapshot ID: \(snapshot.snapshotID)")
            }
            snapshots[snapshot.snapshotID] = snapshot
        }

        // 2. Read frames
        // ----------------------------------------------------------------

        for (frameID, ids) in archive.frames {
            let frame = createFrame(id: frameID)
            for id in ids {
                guard let snapshot = snapshots[id] else {
                    fatalError("Unknown snapshot \(id) in frame \(frameID) during unarchiving")
                }
                frame.unsafeInsert(snapshot, owned: false)
            }
            // We accept the frame making sure that constraints are met.
            // FIXME: We need to mark a frame as "OK" in our (non-corrupted) database, so we do not have to accept it.
            try accept(frame)
        }

        // 2. Read framesets (namely undo and redo)
        // ----------------------------------------------------------------
        let undoFrameset = archive.framesets["undo", default: []]
        let redoFrameset = archive.framesets["redo", default: []]

        guard undoFrameset.allSatisfy( { containsFrame($0) } ) else {
            let offensive = undoFrameset.filter { !containsFrame($0) }
            fatalError("Undo frame-set contains invalid frame references: \(offensive)")
        }

        guard redoFrameset.allSatisfy( { containsFrame($0) } ) else {
            let offensive = redoFrameset.filter { !containsFrame($0) }
            fatalError("Redo frame-set contains invalid frame references: \(offensive)")
        }

        undoableFrames = undoFrameset
        redoableFrames = redoFrameset
        
        if let currentID = archive.info.currentFrameID {
            guard containsFrame(currentID) else {
                fatalError("Current frame not found. ID: \(currentID)")
            }
            currentFrameID = currentID
        }

        // Consistency check: currentFrameID must be set when there is history.
        if currentFrameID == nil
            && (!undoableFrames.isEmpty || !redoableFrames.isEmpty) {
            fatalError("Corrupted archive: Current frame ID is not set while undo/redo history is not-empty")
        }
    }

    
}
