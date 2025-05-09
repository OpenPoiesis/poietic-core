//
//  ForeignDesign.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 01/05/2025.
//


public enum ForeignDesignCompatibility {
    case incompatible
    case needsUpgrade
    case compatible
}

enum RawLoadingResult {
    case ok(Design)
    case error(Error)
    case needsUpgrade(RawDesign)
}

public enum RawObjectID: Equatable, Codable, Sendable, CustomStringConvertible, Hashable {
    case id(ObjectID)
    case int(Int64)
    case string(String)
    
    public var description: String {
        switch self {
        case .id(let value): value.stringValue
        case .int(let value): String(value)
        case .string(let value): value
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        }
        else {
            let value = try container.decode(ObjectID.self)
            self = .id(value)
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .id(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        }
    }
}

extension ObjectID {
    init?(_ raw: RawObjectID) {
        switch raw {
        case let .id(value): self = value
        case let .int(value):
            guard let intValue = UInt64(exactly: value) else { return nil }
            self.init(intValue)
        case let .string(stringValue):
            self.init(stringValue)
        }
    }
}

struct RawNamedReference {
    let name: String
    /// Known types: `frame`, `object`
    let type: String
    let id: RawObjectID
}
struct RawNamedList {
    let name: String
    /// Known types: `frame`
    let itemType: String
    let ids: [RawObjectID]
}

/// Raw representation of a design.
///
/// Raw design representation contains all entities from which a design can be constructed.
/// Raw design does not have to conform to metamodel. The structural integrity is not guaranteed
/// neither checked.
///
public class RawDesign {
    /// Name of the metamodel the raw design represents.
    ///
    /// When loading, the metamodel of the raw design must match metamodel expected by the
    /// application. Metamodel name mismatch should result either in a loading error or in an
    /// upgrade/migration request, if possible.
    ///
    /// When metamodel name is not provided, application should expect the metamodel name to be
    /// as expected by the application. Same for a special metamodel name `"default"`.
    ///
    var metamodelName: String? = nil

    /// Version of the metamodel within the raw design.
    ///
    /// When the version is not matching application expectations, the application should offer
    /// an upgrade to the user, if possible. Otherwise version mismatch should result in an error
    /// and should prevent loading.
    ///
    /// When metamodel version is not provided, application should expect the metamodel version to be
    /// as expected by the application. Guessing a version is considered an act of optional kindness.
    ///
    var metamodelVersion: SemanticVersion? = nil

    /// List of snapshots contained in the raw design.
    ///
    /// Snapshots are expected to be used by the frames. Any snapshot not used by a frame within the
    /// raw design should be discarded during loading process.
    ///
    var snapshots: [RawSnapshot] = []

    /// List of frames.
    ///
    var frames: [RawFrame] = []

    /// References to metamodel entities created by an user, typically through an application.
    ///
    /// For example, ``Design/namedFrames`` are stored here as named references of type `"frame"`.
    ///
    var userReferences: [RawNamedReference] = []

    /// Named lists of references created by an user, typically through an application.
    ///
    /// This is for future extensions and uses. Currently it is ignored and exists for parity
    /// with ``systemLists``.
    ///
    var userLists: [RawNamedList] = []

    /// References to metamodel entities created and managed by the system.
    ///
    /// Currently known and used system references:
    ///
    /// | Name | Type | Description |
    /// | ---- | ---- | ----------- |
    /// | `current_frame` |  `frame` | ID of current frame (see ``Design/currentFrameID``) |
    /// | `application_settings` | `frame` | ID of frame containing application settings. A non-versioned frame. |
    var systemReferences: [RawNamedReference] = []

    /// Named lists of references created by and managed by the system.
    ///
    /// | Name | Item Type | Description |
    /// | ---- | --------- | ----------- |
    /// | `undo` | `frame` | List of undoable frames. See ``Design/undoableFrames`` |
    /// | `redo` | `frame` | List of re-doable frames. See ``Design/redoableFrames`` |
    ///
    var systemLists: [RawNamedList] = []
    
    /// Create a new raw design.
    internal init(metamodelName: String? = nil,
                  metamodelVersion: SemanticVersion? = nil,
                  snapshots: [RawSnapshot] = [],
                  frames: [RawFrame] = [],
                  userReferences: [RawNamedReference] = [],
                  userLists: [RawNamedList] = [],
                  systemReferences: [RawNamedReference] = [],
                  systemLists: [RawNamedList] = []) {
        self.metamodelName = metamodelName
        self.metamodelVersion = metamodelVersion
        self.snapshots = snapshots
        self.frames = frames
        self.userReferences = userReferences
        self.userLists = userLists
        self.systemReferences = systemReferences
        self.systemLists = systemLists
    }
    
///
}

public struct RawStructure {
    var type: String? = nil
    var references: [RawObjectID] = []

    internal init(_ type: String? = nil, references: [RawObjectID] = []) {
        self.type = type
        self.references = references
    }
}

public class RawSnapshot {
    
    var typeName: String? = nil
    var structure: RawStructure = RawStructure(nil, references: [])
    var id: RawObjectID? = nil
    // Must be ObjectID convertible
    var snapshotID: RawObjectID? = nil
    var parent: RawObjectID? = nil
    var attributes: [String:Variant] = [:]
    
    internal init(typeName: String? = nil,
                  snapshotID: RawObjectID? = nil,
                  id: RawObjectID? = nil,
                  structure: RawStructure = RawStructure(nil, references: []),
                  parent: RawObjectID? = nil,
                  attributes: [String:Variant] = [:]) {
        self.typeName = typeName
        self.snapshotID = snapshotID
        self.id = id
        self.structure = structure
        self.parent = parent
        self.attributes = attributes
    }
}

public class RawFrame {
    var id: RawObjectID? = nil
    // TODO: Rename to snapshots
    var objects: [RawObjectID] = []
    internal init(id: RawObjectID? = nil, objects: [RawObjectID] = []) {
        self.id = id
        self.objects = objects
    }
}

