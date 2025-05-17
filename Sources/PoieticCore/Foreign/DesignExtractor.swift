//
//  RawDesignExporter.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 09/05/2025.
//


/// Object that exports a design into a raw design representation for foreign interfaces or for
/// unsafe structural surgeries.
///
public class DesignExtractor {
    
    public init() {
        // Nothing for now
    }
   // FIXME: Rename to RawDesignExtractor
    /// Create a raw design from a design.
    ///
    /// - SeeAlso: ``extract(_:)``, ``RawDesign``, ``RawSnapshot``
    ///
    public func extract(_ design: Design) -> RawDesign {
        var snapshots: [RawSnapshot] = []
        var frames: [RawFrame] = []
        var sysLists: [RawNamedList] = []
        let sysReferences: [RawNamedReference]
        var userReferences: [RawNamedReference] = []

        // 1. Snapshots and frames
        for snapshot in design.snapshots {
            let raw = extract(snapshot)
            snapshots.append(raw)
        }
        for frame in design.frames {
            let raw = extract(frame)
            frames.append(raw)
        }
        
        // 2. System named lists and system named references
        // Write only non-empty ones and non-nil ones (can't write nil ref anyway).
        if !design.undoableFrames.isEmpty {
            let undoList: [RawObjectID] = design.undoableFrames.map { .id($0) }
            sysLists.append(RawNamedList("undo", itemType: "frame", ids: undoList))
        }
        if !design.redoableFrames.isEmpty {
            let redoList: [RawObjectID] = design.redoableFrames.map { .id($0) }
            sysLists.append(RawNamedList("redo", itemType: "frame", ids: redoList))
        }
        
        if let id = design.currentFrameID {
            sysReferences = [
                RawNamedReference("current_frame", type: "frame", id: .id(id))
            ]
        }
        else {
            sysReferences = []
        }

        // 3. User references
        // Write all, including empty ones.
        for (name, frame) in design.namedFrames {
            let ref = RawNamedReference(name, type: "frame", id: .id(frame.id))
            userReferences.append(ref)
        }
        
        let rawDesign = RawDesign(
            metamodelName: design.metamodel.name,
            metamodelVersion: design.metamodel.version,
            snapshots: snapshots,
            frames: frames,
            userReferences: userReferences,
            systemReferences: sysReferences,
            systemLists: sysLists
        )
        
        return rawDesign
    }
    
    /// Extract basic raw design attributes without any actual content.
    ///
    /// Use this method to manually populate the raw design.
    ///
    public func extractStub(_ design: Design) -> RawDesign {
        let rawDesign = RawDesign(
            metamodelName: design.metamodel.name,
            metamodelVersion: design.metamodel.version,
        )
        
        return rawDesign
    }

    
    /// Create a raw snapshot representation from a design snapshot.
    ///
    /// - SeeAlso: ``extract(_:)``
    ///
    public func extract(_ snapshot: DesignObject) -> RawSnapshot {
        let rawParent: RawObjectID? = snapshot.parent.map { .id($0) }
        let raw = RawSnapshot(
            typeName: snapshot.type.name,
            snapshotID: .id(snapshot.snapshotID),
            id: .id(snapshot.id),
            structure: RawStructure(snapshot.structure),
            parent: rawParent,
            attributes: snapshot.attributes
        )
        return raw
    }
    
    /// Create a raw frame from a design frame.
    ///
    public func extract(_ frame: DesignFrame) -> RawFrame {
        return RawFrame(
            id: .id(frame.id),
            snapshots: frame.snapshots.map { .id($0.snapshotID) }
        )
    }
    
    /// Extract snapshots from a frame while maintaining referential integrity.
    ///
    /// This method is intended primarily for the "copy" part of the Copy&Paste functionality. Can
    /// be used for safely exporting portions of designs.
    ///
    /// The pruning rules:
    ///
    /// - All nodes and unstructured objects are kept.
    /// - Only edges with endpoints within the provided set of snapshots are kept, others
    ///   are not included in the result.
    /// - Only ordered set (structural type) with the owner in the provided set of snapshots are kept.
    /// - Invalid references in the ordered set structural type are removed, but the ordered set is kept.
    /// - Missing parent is set to `nil`.
    /// - Snapshots not present in the frame are ignored.
    ///
    public func extractPruning(snapshots: [ObjectID], frame: DesignFrame) -> [RawSnapshot] {
        let knownIDs: Set<ObjectID> = Set(snapshots)
        var result: [RawSnapshot] = []
        
        
        for id in snapshots {
            guard frame.contains(id) else {
                continue
            }
            let snapshot = frame[id]
            let raw: RawSnapshot
            
            switch snapshot.structure {
            case .unstructured, .node:
                raw = extract(snapshot)
            case let .edge(origin, target):
                guard knownIDs.contains(origin) && knownIDs.contains(target) else {
                    continue
                }
                raw = extract(snapshot)
            case let .orderedSet(owner, items):
                guard knownIDs.contains(owner) else {
                    continue
                }
                let knownItems = items.filter { knownIDs.contains($0) }
                raw = extract(snapshot)
                raw.structure.references = knownItems.map { .id($0) }
            }
            
            if let parent = snapshot.parent, !knownIDs.contains(parent) {
                raw.parent = nil
            }
            result.append(raw)
        }

        return result
    }
}
