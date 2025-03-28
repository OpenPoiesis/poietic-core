//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 21/10/2023.
//

import Foundation

/// Structure for makeshift persistent store.
///
struct _PersistentSnapshot: Codable {
    let id: ObjectID
    let snapshotID: ObjectID
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
}

/// Structure for makeshift persistent store.
///
struct _PersistentFrame: Codable {
    let id: ObjectID
    let snapshots: [ObjectID]
}

/// Structure for makeshift persistent store.
///
struct _PersistentDesignState: Codable {
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
struct _PersistentDesign: Codable {
    let storeFormatVersion: String
    let metamodel: String
    let snapshots: [_PersistentSnapshot]
    let frames: [_PersistentFrame]
    let state: _PersistentDesignState
    let namedFrames: [String:ObjectID]?
    enum CodingKeys: String, CodingKey {
        case storeFormatVersion = "store_format_version"
        case metamodel
        case snapshots
        case frames
        case state
        case namedFrames = "named_frames"
    }
}
