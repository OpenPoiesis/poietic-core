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
    public func load(metamodel: Metamodel = Metamodel()) throws -> Design {
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
        catch DecodingError.dataCorrupted(_){
            throw PersistentStoreError.dataCorrupted
        }
        catch let DecodingError.keyNotFound(key, context) {
            let path = context.codingPath.map { $0.stringValue }
            throw PersistentStoreError.missingProperty(key.stringValue, path)
        }
        catch let DecodingError.typeMismatch(_, context) {
            let path = context.codingPath.map { $0.stringValue }
            throw PersistentStoreError.typeMismatch(path)
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

    func restoreCurrentVersion(_ persistent: _PersistentDesign, metamodel: Metamodel) throws (PersistentStoreError) -> Design {
        let design = Design(metamodel: metamodel)

        // 1. Read Snapshots
        // ----------------------------------------------------------------
        var snapshots: [SnapshotID: ObjectSnapshot] = [:]

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
            
            let structure: StructuralComponent
            switch type.structuralType {
            case .unstructured:
                guard perSnapshot.origin == nil else {
                    throw .extraneousStructuralProperty(type.structuralType, "origin")
                }
                guard perSnapshot.target == nil else {
                    throw .extraneousStructuralProperty(type.structuralType, "target")
                }
                structure = .unstructured
            case .node:
                guard perSnapshot.origin == nil else {
                    throw .extraneousStructuralProperty(type.structuralType, "origin")
                }
                guard perSnapshot.target == nil else {
                    throw .extraneousStructuralProperty(type.structuralType, "target")
                }
                structure = .node
            case .edge:
                guard let origin = perSnapshot.origin else {
                    throw .missingStructuralProperty(type.structuralType, "from")
                }
                guard let target = perSnapshot.target else {
                    throw .missingStructuralProperty(type.structuralType, "to")
                }
                structure = .edge(ObjectID(origin), ObjectID(target))
            }

            let snapshot = ObjectSnapshot(id: perSnapshot.id,
                                          snapshotID: perSnapshot.snapshotID,
                                          type: type,
                                          structure: structure,
                                          parent: perSnapshot.parent,
                                          attributes: perSnapshot.attributes,
                                          components: [])

            // FIXME: [REFACTORING] Were are we fixing children?
            snapshot.promote(.stable)
            snapshots[snapshot.snapshotID] = snapshot
        }

        // 2. Read frames
        // ----------------------------------------------------------------
        for perFrame in persistent.frames {
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
            // We accept the frame making sure that constraints are met.
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
        
        for snapshot in design.validatedSnapshots {
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
        
        let state = _PersistentDesignState(currentFrame: design.currentFrameID,
                                           undoableFrames: design.undoableFrames,
                                           redoableFrames: design.redoableFrames)
        let perDesign = _PersistentDesign(
            storeFormatVersion: Self.FormatVersion,
            metamodel: "DEFAULT",
            snapshots: snapshots,
            frames: frames,
            state: state
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

