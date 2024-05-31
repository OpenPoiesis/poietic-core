//
//  File.swift
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
/// - Note: This is a solution before we get a proper store design.
///
public class MakeshiftDesignStore {
    static let FormatVersion = "0.0.4"
    
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
    func restore(_ perDesign: _PersistentDesign, metamodel: Metamodel) throws -> Design {
        let design = Design(metamodel: metamodel)

        // TODO: Handle different versions here
        if perDesign.storeFormatVersion != MakeshiftDesignStore.FormatVersion {
            throw PersistentStoreError.unsupportedFormatVersion(perDesign.storeFormatVersion)
        }

        // 1. Read Snapshots
        // ----------------------------------------------------------------
        var snapshots: [SnapshotID: ObjectSnapshot] = [:]
        
        for perSnapshot in perDesign.snapshots {
            guard let type = metamodel.objectType(name: perSnapshot.type) else {
                throw PersistentStoreError.unknownObjectType(perSnapshot.type)
            }

            guard let structuralType = StructuralType(rawValue: perSnapshot.structuralType) else {
                throw PersistentStoreError.invalidStructuralType(perSnapshot.structuralType)
            }
            guard type.structuralType == structuralType else {
                throw PersistentStoreError.structuralTypeMismatch(type.structuralType,
                                                                  structuralType)
            }

            guard snapshots[perSnapshot.snapshotID] == nil else {
                throw PersistentStoreError.duplicateSnapshot(perSnapshot.snapshotID)
            }
            
            let structure: StructuralComponent
            switch type.structuralType {
            case .unstructured:
                guard perSnapshot.origin == nil else {
                    throw PersistentStoreError.extraneousStructuralProperty(type.structuralType, "origin")
                }
                guard perSnapshot.target == nil else {
                    throw PersistentStoreError.extraneousStructuralProperty(type.structuralType, "target")
                }
                structure = .unstructured
            case .node:
                guard perSnapshot.origin == nil else {
                    throw PersistentStoreError.extraneousStructuralProperty(type.structuralType, "origin")
                }
                guard perSnapshot.target == nil else {
                    throw PersistentStoreError.extraneousStructuralProperty(type.structuralType, "target")
                }
                structure = .node
            case .edge:
                guard let origin = perSnapshot.origin else {
                    throw PersistentStoreError.missingStructuralProperty(type.structuralType, "from")
                }
                guard let target = perSnapshot.target else {
                    throw PersistentStoreError.missingStructuralProperty(type.structuralType, "to")
                }
                structure = .edge(ObjectID(origin), ObjectID(target))
            }

            let snapshot = design.createSnapshot(type,
                                                 id: perSnapshot.id,
                                                 snapshotID: perSnapshot.snapshotID,
                                                 structure: structure,
                                                 parent: perSnapshot.parent,
                                                 attributes: perSnapshot.attributes,
                                                 components: [],
                                                 state: .validated)


            snapshots[snapshot.snapshotID] = snapshot
//            snapshot.promote(.validated)
        }

        // 3. Read frames
        // ----------------------------------------------------------------

        for perFrame in perDesign.frames {
            if design.containsFrame(perFrame.id) {
                throw PersistentStoreError.duplicateFrame(perFrame.id)
            }
            
            let frame = design.createFrame(id: perFrame.id)
            
            for id in perFrame.snapshots {
                guard let snapshot = snapshots[id] else {
                    throw PersistentStoreError.invalidSnapshotReference(frame.id, id)
                }
                // Do not check for referential integrity yet
                frame.unsafeInsert(snapshot, owned: false)
            }
            // We accept the frame making sure that constraints are met.
            try design.accept(frame)
        }

        // 4. Design state (undo, redo, current frame)
        // ----------------------------------------------------------------
        
        for item in perDesign.state.undoableFrames {
            if !design.containsFrame(item) {
                throw PersistentStoreError.invalidFrameReference("undoable_frames", item)
            }
        }
        design.undoableFrames = perDesign.state.undoableFrames

        for item in perDesign.state.redoableFrames {
            if !design.containsFrame(item) {
                throw PersistentStoreError.invalidFrameReference("redoable_frames", item)
            }
        }
        design.redoableFrames = perDesign.state.redoableFrames

        // Consistency check: currentFrameID must be set when there is history.
        if perDesign.state.currentFrame == nil
            && (!design.undoableFrames.isEmpty || !design.redoableFrames.isEmpty) {
            throw PersistentStoreError.currentFrameIDNotSet
        }
        design.currentFrameID = perDesign.state.currentFrame

        return design
    }
    
    public func save(design: Design) throws {
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
        
        let data = try encoder.encode(perDesign)
        try data.write(to: url)
    }
}

