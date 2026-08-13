//
//  MakeshiftPersistentDesign.swift
//
//
//  Created by Stefan Urbanek on 21/10/2023.
//

// TODO: [IMPORTANT] Remove this legacy code once everything is converted as needed.

import Foundation

/// Structure for makeshift persistent store.
///
struct _MakeshiftPersistentSnapshot: Codable {
    let id: ObjectID
    let snapshotID: ObjectSnapshotID
    let type: String
    let structuralType: String
    let origin: ObjectID?
    let target: ObjectID?
    let parent: ObjectID?
    let attributes: [String:Variant]

    enum CodingKeys: String, CodingKey {
        case id
        case snapshotID = "snapshot_id"
        case type
        case structuralType = "structural_type"
        case origin
        case target
        case parent
        case attributes
    }
    
    func asRawSnapshot() -> RawSnapshot {
        var structure: RawTopology
        switch structuralType {
        case "unstructured": structure = RawTopology("unstructured")
        case "node": structure = RawTopology("node")
        case "edge":
            guard let origin = self.origin else {
                structure = RawTopology("edge-missing-origin")
                break
            }
            guard let target = self.target else {
                structure = RawTopology("edge-missing-target")
                break
            }
            structure = RawTopology("edge", references: [.id(origin), .id(target)])
        default: structure = RawTopology(structuralType)
        }
        let snapshot = RawSnapshot(
            typeName: type,
            snapshotID: .id(snapshotID),
            objectID: .id(id),
            topology: structure,
            parent: parent.map { .id($0) },
            attributes: attributes
        )
        return snapshot
    }
}

/// Structure for makeshift persistent store.
///
struct _MakeshiftPersistentFrame: Codable {
    let id: ObjectID
    let snapshots: [ObjectID]
    
    func asRawFrame() -> RawPlane {
        return RawPlane(
            id: .id(id),
            snapshots: snapshots.map { .id($0) }
        )
    }
}

/// Structure for makeshift persistent store.
///
struct _MakeshiftPersistentDesignState: Codable {
    let currentFrame: ObjectID?
    let undoableFrames: [ObjectID]
    let redoableFrames: [ObjectID]
    enum CodingKeys: String, CodingKey {
        case currentFrame = "current_frame"
        case undoableFrames = "undoable_frames"
        case redoableFrames = "redoable_frames"
    }
}

/// Root structure for makeshift persistent store.
///
struct _MakeshiftPersistentDesign: Codable {
    let storeFormatVersion: String?
    let metamodel: String
    let snapshots: [_MakeshiftPersistentSnapshot]
    let frames: [_MakeshiftPersistentFrame]
    let state: _MakeshiftPersistentDesignState
    let namedFrames: [String:ObjectID]?
    enum CodingKeys: String, CodingKey {
        case storeFormatVersion = "store_format_version"
        case metamodel
        case snapshots
        case frames
        case state
        case namedFrames = "named_frames"
    }
    
    func asRawDesign() -> RawDesign {
        let design = RawDesign()
        
        design.metamodelName = self.metamodel
        design.snapshots = self.snapshots.map { $0.asRawSnapshot() }
        design.planes = self.frames.map { $0.asRawFrame() }
        if let currentFrame = state.currentFrame {
            design.systemReferences = [
                RawNamedReference("current_plane", type: "plane", id: .id(currentFrame))
            ]
        }
        var systemLists: [RawNamedList] = []
        if !state.undoableFrames.isEmpty {
            let list = RawNamedList("undo",
                                    itemType: "plane",
                                    ids: state.undoableFrames.map {.id($0)})
            systemLists.append(list)
        }
        if !state.redoableFrames.isEmpty {
            let list = RawNamedList("redo",
                                    itemType: "plane",
                                    ids: state.redoableFrames.map {.id($0)})
            systemLists.append(list)
        }
        design.systemLists = systemLists

        var userReferences: [RawNamedReference] = []
        if let namedFrames {
            for (name, frameID) in namedFrames {
                let ref = RawNamedReference(name, type: "plane", id: .id(frameID))
                userReferences.append(ref)
            }
        }
        design.userReferences = userReferences

        return design
    }
}
