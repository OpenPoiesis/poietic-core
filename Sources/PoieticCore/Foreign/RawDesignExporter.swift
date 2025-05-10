//
//  RawDesignExporter.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 09/05/2025.
//

class RawDesignExporter {
    func export(_ design: Design) -> RawDesign {
        var snapshots: [RawSnapshot] = []
        var frames: [RawFrame] = []
        
        // 1. Snapshots and frames
        for snapshot in design.snapshots {
            let raw = export(snapshot)
            snapshots.append(raw)
        }
        for frame in design.frames {
            let raw = export(frame)
            frames.append(raw)
        }
        

        // 2. System named lists and system named references
        // Write only non-empty ones and non-nil ones (can't write nil ref anyway).
        
        var sysLists: [RawNamedList] = []

        if !design.undoableFrames.isEmpty {
            let undoList: [RawObjectID] = design.undoableFrames.map { .id($0) }
            sysLists.append(RawNamedList("undo", itemType: "frame", ids: undoList))
        }
        if !design.redoableFrames.isEmpty {
            let redoList: [RawObjectID] = design.redoableFrames.map { .id($0) }
            sysLists.append(RawNamedList("redo", itemType: "frame", ids: redoList))
        }

        let sysReferences: [RawNamedReference]
        
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
        
        var userReferences: [RawNamedReference] = []
        for (name, frame) in design.namedFrames {
            let ref = RawNamedReference(name, type: "frame", id: .id(frame.id))
            userReferences.append(ref)
        }
        
        let rawDesign = RawDesign(
            metamodelName: design.metamodel.name,
            metamodelVersion: nil, // FIXME: [WIP] Fill-in from metamodel (not yet there)
            snapshots: snapshots,
            frames: frames,
            userReferences: userReferences,
            systemReferences: sysReferences,
            systemLists: sysLists
        )
        
        return rawDesign
    }
    
    func export(_ snapshot: DesignObject) -> RawSnapshot {
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
    
    func export(_ frame: DesignFrame) -> RawFrame {
        return RawFrame(
            id: .id(frame.id),
            snapshots: frame.snapshots.map { .id($0.snapshotID) }
        )
    }
    
}
