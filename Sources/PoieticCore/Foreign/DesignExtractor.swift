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
        for snapshot in design.objectSnapshots {
            let raw = extract(snapshot)
            snapshots.append(raw)
        }
        for frame in design.frames {
            let raw = extract(frame)
            frames.append(raw)
        }
        
        // 2. System named lists and system named references
        // Write only non-empty ones and non-nil ones (can't write nil ref anyway).
        if !design.undoList.isEmpty {
            let undoList: [ForeignEntityID] = design.undoList.map { .id($0.rawValue) }
            sysLists.append(RawNamedList("undo", itemType: "frame", ids: undoList))
        }
        if !design.redoList.isEmpty {
            let redoList: [ForeignEntityID] = design.redoList.map { .id($0.rawValue) }
            sysLists.append(RawNamedList("redo", itemType: "frame", ids: redoList))
        }
        
        if let id = design.currentFrameID {
            sysReferences = [
                RawNamedReference("current_frame", type: "frame", id: .id(id.rawValue))
            ]
        }
        else {
            sysReferences = []
        }

        // 3. User references
        // Write all, including empty ones.
        for (name, frame) in design.namedFrames {
            let ref = RawNamedReference(name, type: "frame", id: .id(frame.id.rawValue))
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
    public func extract(_ snapshot: ObjectSnapshot) -> RawSnapshot {
        let rawParent: ForeignEntityID? = snapshot.parent.map { .id($0.rawValue) }
        let raw = RawSnapshot(
            typeName: snapshot.type.name,
            snapshotID: .id(snapshot.snapshotID.rawValue),
            id: .id(snapshot.objectID.rawValue),
            structure: RawStructure(snapshot.structure),
            parent: rawParent,
            attributes: snapshot.attributes
        )
        return raw
    }
    
    /// Create a raw frame from a design frame.
    ///
    public func extract(_ frame: some Frame) -> RawFrame {
        return RawFrame(
            id: .id(frame.id.rawValue),
            snapshots: frame.snapshots.map { .id($0.snapshotID.rawValue) }
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
    public func extractPruning(objects objectIDs: [ObjectID], frame: some Frame) -> [RawSnapshot] {
        let knownIDs: Set<ObjectID> = Set(objectIDs)
        var result: [RawSnapshot] = []
        
        
        for id in objectIDs {
            guard let snapshot = frame[id] else { continue }
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
                raw.structure.references = knownItems.map { .id($0.rawValue) }
            }
            
            if let parent = snapshot.parent, !knownIDs.contains(parent) {
                raw.parent = nil
            }
            result.append(raw)
        }

        return result
    }
}
