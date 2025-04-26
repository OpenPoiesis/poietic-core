//
//  MakeshiftDesignStore.swift
//
//
//  Created by Stefan Urbanek on 20/10/2023.
//

import Foundation

/// A makeshift persistent store.
///
/// Makeshift persistent design store stores the design as a JSON generated
/// by the Swift _Codable_ protocol.
///
/// - Note: The reason we are using the `Codable` protocol is that the Swift
/// Foundation (at this time) does not have a viable reading/writing of raw JSON
/// that is not bound to the Codable protocol. We need raw reading/writing to
/// adapt for potential version changes of the file being read and for
/// better error reporting.
/// 
/// - Note: This is a solution before we get a proper store design.
///
public class MakeshiftDesignStore {
    // Development note: The format version should be the latest version tag
    // when the format has changed.
    //
    static let FormatVersion = "0.3"
    
    public let data: Data?
    public let url: URL?

    /// Create a new makeshift store from data containing a JSON structure.
    ///
    public init(data: Data?=nil, url: URL?=nil) {
        self.url = url
        self.data = data
    }

    /// Load and restore a design from the store.
    ///
    /// - Returns: Restored ``Design`` object.
    /// - Throws: ``PersistentStoreError``.
    ///
    public func load(metamodel: Metamodel = Metamodel()) throws (PersistentStoreError) -> Design {
        let data: Data
        if let providedData = self.data {
            data = providedData
        }
        else {
            guard let url = self.url else {
                throw PersistentStoreError.storeMissing
            }
            do {
                data = try Data(contentsOf: url)
            }
            catch {
                throw PersistentStoreError.cannotOpenStore(url)
            }
        }

        let decoder = JSONDecoder()
        // decoder.userInfo[Self.FormatVersionKey] = Self.FormatVersion
        
        let perDesign: _PersistentDesign
        do {
            perDesign = try decoder.decode(_PersistentDesign.self, from: data)
        }
        catch let error as DecodingError {
            switch error {
            case .dataCorrupted(_):
                throw .dataCorrupted
            case let .keyNotFound(key, context):
                let path = context.codingPath.map { $0.stringValue }
                throw .missingProperty(key.stringValue, path)
            case let .typeMismatch(_, context):
                let path = context.codingPath.map { $0.stringValue }
                throw .typeMismatch(path)
            case let .valueNotFound(key, context):
                let path = context.codingPath.map { $0.stringValue }
                throw .missingValue(String(describing: key), path)
            @unknown default:
                throw .unhandledError("Unknown decoding error case: \(error)")
            }
        }
        catch {
            throw .unhandledError("Unknown decoding error: \(error)")
        }

        return try restore(perDesign, metamodel: metamodel)
    }
    
    /// Restore a design from the store.
    ///
    /// - Returns: Restored ``Design`` object.
    /// - Throws: ``PersistentStoreError``.
    ///
    func restore(_ perDesign: _PersistentDesign, metamodel: Metamodel) throws (PersistentStoreError) -> Design {
        switch perDesign.storeFormatVersion {
        case "0.0.4", Self.FormatVersion:
            return try restoreCurrentVersion(perDesign, metamodel: metamodel)
        // case "x.y.z":
        //     return try restoreVersionX_Y_Z(perDesign, metamodel: metamodel)
        default:
            throw .unsupportedFormatVersion(perDesign.storeFormatVersion)
        }
    }

    
    func assertUniqueID(_ id: ObjectID, in design: Design, context: String) throws (PersistentStoreError) {
        guard design.isUnused(id) else {
            throw .duplicateID(id, context)
        }
        design.consumeID(id)
    }

    func restoreCurrentVersion(_ persistent: _PersistentDesign, metamodel: Metamodel) throws (PersistentStoreError) -> Design {

        let design = Design(metamodel: metamodel)

        // 1. Read Snapshots
        // ----------------------------------------------------------------
        var snapshots: [SnapshotID: DesignObject] = [:]

        for perSnapshot in persistent.snapshots {
            guard let type = metamodel.objectType(name: perSnapshot.type) else {
                throw .unknownObjectType(perSnapshot.type)
            }

            guard let structuralType = StructuralType(rawValue: perSnapshot.structuralType) else {
                throw .invalidStructuralType(perSnapshot.structuralType)
            }
            guard type.structuralType == structuralType else {
                throw .structuralTypeMismatch(type.structuralType, structuralType)
            }

            guard snapshots[perSnapshot.snapshotID] == nil else {
                throw .duplicateSnapshot(perSnapshot.snapshotID)
            }
            
            let structure: Structure
            switch type.structuralType {
            case .unstructured:
                structure = .unstructured
            case .node:
                structure = .node
            case .edge:
                guard let origin = perSnapshot.origin else {
                    throw .missingStructuralProperty(type.structuralType, "from")
                }
                guard let target = perSnapshot.target else {
                    throw .missingStructuralProperty(type.structuralType, "to")
                }
                structure = .edge(origin, target)
            case .orderedSet:
                // FIXME: [WIP] Implement this
                fatalError("NOT IMPLEMENTED")
            }
            // TODO: Handle corrupted store with existing IDs
            // TODO: Handle corrupted store with duplicate objectIDs within frame
            design.consumeID(perSnapshot.id)
            try assertUniqueID(perSnapshot.snapshotID, in: design, context: "snapshot")

            let snapshot = DesignObject(id: perSnapshot.id,
                                        snapshotID: perSnapshot.snapshotID,
                                        type: type,
                                        structure: structure,
                                        parent: perSnapshot.parent,
                                        attributes: perSnapshot.attributes,
                                        components: [])

            snapshots[snapshot.snapshotID] = snapshot
        }

        // 2. Read frames
        // ----------------------------------------------------------------
        for perFrame in persistent.frames {
            try assertUniqueID(perFrame.id, in: design, context: "frame")
            if design.containsFrame(perFrame.id) {
                throw .duplicateFrame(perFrame.id)
            }
            
            let newFrame = design.createFrame(id: perFrame.id)
            
            for id in perFrame.snapshots {
                guard let snapshot = snapshots[id] else {
                    throw .invalidSnapshotReference(newFrame.id, id)
                }
                // Do not check for referential integrity yet
                newFrame.unsafeInsert(snapshot)
            }
            // We accept the frame making sure that structural integrity is satisfied
            do {
                try design.accept(newFrame)
            }
            catch {
                throw .frameValidationFailed(newFrame.id)
            }
        }

        // 3. Design state (undo, redo, current frame)
        // ----------------------------------------------------------------
        
        for item in persistent.state.undoableFrames {
            if !design.containsFrame(item) {
                throw PersistentStoreError.invalidFrameReference("undoable_frames", item)
            }
        }
        design.undoableFrames = persistent.state.undoableFrames

        for item in persistent.state.redoableFrames {
            if !design.containsFrame(item) {
                throw PersistentStoreError.invalidFrameReference("redoable_frames", item)
            }
        }
        design.redoableFrames = persistent.state.redoableFrames

        // Consistency check: currentFrameID must be set when there is history.
        if persistent.state.currentFrame == nil
            && (!design.undoableFrames.isEmpty || !design.redoableFrames.isEmpty) {
            throw PersistentStoreError.currentFrameIDNotSet
        }
        design.currentFrameID = persistent.state.currentFrame
        
        var namedFrames: [String:DesignFrame] = [:]
        if let named = persistent.namedFrames {
            for (name, id) in named {
                guard let frame = design.frame(id) else {
                    throw PersistentStoreError.invalidFrameReference("named_frames.\(name)", id)
                }
                guard !design.undoableFrames.contains(id)
                        && !design.redoableFrames.contains(id)
                        && design.currentFrameID != id else {
                    throw PersistentStoreError.illegalFrameAssignment(id)

                }
                namedFrames[name] = frame
            }
            design._namedFrames = namedFrames
        }
        
        return design
    }
    
    /// Save the design to store's URL.
    ///
    /// - Throws: ``PersistentStoreError/unableToWrite(_:)``
    public func save(design: Design) throws (PersistentStoreError) {
        guard let url = self.url else {
            fatalError("No store URL set to save design to.")
        }
        var snapshots: [_PersistentSnapshot] = []
        var frames: [_PersistentFrame] = []
        var namedFrames: [String:ObjectID] = [:]

        for snapshot in design.snapshots {
            let origin: ObjectID?
            let target: ObjectID?
            switch snapshot.structure {
            case .edge(let sOrigin, let sTarget):
                (origin, target) = (sOrigin, sTarget)
            default:
                (origin, target) = (nil, nil)
            }
            
            let perSnapshot = _PersistentSnapshot(
                id: snapshot.id,
                snapshotID: snapshot.snapshotID,
                type: snapshot.type.name,
                structuralType: snapshot.structure.type.rawValue,
                origin: origin,
                target: target,
                parent: snapshot.parent,
                attributes: snapshot.attributes
            )
            snapshots.append(perSnapshot)
        }
        
        for frame in design.frames {
            let ids = frame.snapshots.map { $0.snapshotID }
            let perFrame = _PersistentFrame(id: frame.id,
                                            snapshots: ids)
            frames.append(perFrame)
        }
        
        for (key, value) in design._namedFrames {
            namedFrames[key] = value.id
        }
        
        let state = _PersistentDesignState(currentFrame: design.currentFrameID,
                                           undoableFrames: design.undoableFrames,
                                           redoableFrames: design.redoableFrames)
        let perDesign = _PersistentDesign(
            storeFormatVersion: Self.FormatVersion,
            metamodel: "DEFAULT",
            snapshots: snapshots,
            frames: frames,
            state: state,
            namedFrames: namedFrames
        )
        
        let encoder = JSONEncoder()
        
        let data: Data
        do {
            data = try encoder.encode(perDesign)
        }
        catch {
            // Not user's fault, it is ours.
            fatalError("Unable to encode design for persistent store. Underlying error: \(error)")
        }
        
        do {
            try data.write(to: url)
        }
        catch {
            throw .unableToWrite(url)
        }
    }
}

