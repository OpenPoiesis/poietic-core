//
//  ForeignDesign.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 01/05/2025.
//

// TODO: [IMPORTANT] [WIP] Parent loading is not implemented

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

public struct RawNamedReference: Equatable, Codable {
    public let name: String
    /// Known types: `frame`, `object`
    public let type: String
    public let id: RawObjectID

    public init(_ name: String, type: String, id: RawObjectID) {
        self.name = name
        self.type = type
        self.id = id
    }
}

public struct RawNamedList: Equatable, Codable {
    public let name: String
    /// Known types: `frame`
    public let itemType: String
    public let ids: [RawObjectID]

    enum CodingKeys: String, CodingKey {
        case name
        case itemType = "item_type"
        case ids
    }

    public init(_ name: String, itemType: String, ids: [RawObjectID]) {
        self.name = name
        self.itemType = itemType
        self.ids = ids
    }
}

/// Raw representation of a design.
///
/// Raw design representation contains all entities from which a design can be constructed.
/// Raw design does not have to conform to metamodel. The structural integrity is not guaranteed
/// neither checked.
///
public class RawDesign: Codable {
    /// Name of the metamodel the raw design represents.
    ///
    /// When loading, the metamodel of the raw design must match metamodel expected by the
    /// application. Metamodel name mismatch should result either in a loading error or in an
    /// upgrade/migration request, if possible.
    ///
    /// When metamodel name is not provided, application should expect the metamodel name to be
    /// as expected by the application. Same for a special metamodel name `"default"`.
    ///
    public var metamodelName: String? = nil

    /// Version of the metamodel within the raw design.
    ///
    /// When the version is not matching application expectations, the application should offer
    /// an upgrade to the user, if possible. Otherwise version mismatch should result in an error
    /// and should prevent loading.
    ///
    /// When metamodel version is not provided, application should expect the metamodel version to be
    /// as expected by the application. Guessing a version is considered an act of optional kindness.
    ///
    public var metamodelVersion: SemanticVersion? = nil

    /// List of snapshots contained in the raw design.
    ///
    /// Snapshots are expected to be used by the frames. Any snapshot not used by a frame within the
    /// raw design should be discarded during loading process.
    ///
    public var snapshots: [RawSnapshot] = []

    /// List of frames.
    ///
    public var frames: [RawFrame] = []

    /// References to metamodel entities created by an user, typically through an application.
    ///
    /// For example, ``Design/namedFrames`` are stored here as named references of type `"frame"`.
    ///
    public var userReferences: [RawNamedReference] = []

    /// Named lists of references created by an user, typically through an application.
    ///
    /// This is for future extensions and uses. Currently it is ignored and exists for parity
    /// with ``systemLists``.
    ///
    public var userLists: [RawNamedList] = []

    /// References to metamodel entities created and managed by the system.
    ///
    /// Currently known and used system references:
    ///
    /// | Name | Type | Description |
    /// | ---- | ---- | ----------- |
    /// | `current_frame` |  `frame` | ID of current frame (see ``Design/currentFrameID``) |
    /// | `application_settings` | `frame` | ID of frame containing application settings. A non-versioned frame. |
    public var systemReferences: [RawNamedReference] = []

    /// Named lists of references created by and managed by the system.
    ///
    /// | Name | Item Type | Description |
    /// | ---- | --------- | ----------- |
    /// | `undo` | `frame` | List of undoable frames. See ``Design/undoableFrames`` |
    /// | `redo` | `frame` | List of re-doable frames. See ``Design/redoableFrames`` |
    ///
    public var systemLists: [RawNamedList] = []
    
    /// Dictionary to capture properties of older versions.
    ///
    /// Known properties:
    ///
    /// - `collections: [String]`
    public var _compatibility: [String:Any] = [:]
    
    /// Create a new raw design.
    public init(metamodelName: String? = nil,
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
    
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"

        case metamodelName = "metamodel"
        case metamodelVersion = "metamodel_version"
        case snapshots
        case frames
        case userReferences = "user_references"
        case systemReferences = "system_references"
        case userLists = "user_lists"
        case systemLists = "system_lists"
        
        // TODO: Remove these. Used during prototyping.
        case _makeshiftStoreFormatVersion = "store_format_version"
        case _collections = "collections"
        case _objects = "objects"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys)
        try container.encode(JSONDesignReader.CurrentFormatVersion.description, forKey: .formatVersion)
        try container.encodeIfPresent(metamodelName, forKey: .metamodelName)
        try container.encodeIfPresent(metamodelVersion?.description, forKey: .metamodelVersion)
        if !snapshots.isEmpty {
            try container.encode(snapshots, forKey: .snapshots)
        }
        if !frames.isEmpty {
            try container.encode(frames, forKey: .frames)
        }
        if !userReferences.isEmpty {
            try container.encode(userReferences, forKey: .userReferences)
        }
        if !systemReferences.isEmpty {
            try container.encode(systemReferences, forKey: .systemReferences)
        }
        if !userLists.isEmpty {
            try container.encode(userLists, forKey: .userLists)
        }
        if !systemLists.isEmpty {
            try container.encode(systemLists, forKey: .systemLists)
        }
    }
    
    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys)
        let versionString = try container.decodeIfPresent(String.self, forKey: .formatVersion)
        
        if let versionString {
            guard let version = SemanticVersion(versionString) else {
                throw RawDesignReaderError.unknownFormatVersion(versionString)
            }
            guard version == SemanticVersion(0,1,0) else {
                // TODO: Remove backward compatibility with makeshift (not public)
                throw RawDesignReaderError.unknownFormatVersion(versionString)
            }
        }
        if let _makeshiftVersion = try container.decodeIfPresent(String.self, forKey: ._makeshiftStoreFormatVersion) {
            throw RawDesignReaderError.unknownFormatVersion("makeshift_store")
        }
        
        self.metamodelName = try container.decodeIfPresent(String.self, forKey: .metamodelName)
        let metamodelVersionString = try container.decodeIfPresent(String.self, forKey: .metamodelVersion)
        if let metamodelVersionString, let version = SemanticVersion(metamodelVersionString) {
            self.metamodelVersion = version
        }
        if let snapshots = try container.decodeIfPresent([RawSnapshot].self, forKey: .snapshots) {
            self.snapshots = snapshots
        }
        else if let snapshots = try container.decodeIfPresent([RawSnapshot].self, forKey: ._objects) {
            self.snapshots = snapshots
        }
        else {
            self.snapshots = []
        }
        if let frames = try container.decodeIfPresent([RawFrame].self, forKey: .frames) {
            self.frames = frames
        }
        else {
            self.frames = []
        }
        if let refs = try container.decodeIfPresent([RawNamedReference].self, forKey: .userReferences) {
            self.userReferences = refs
        }
        else {
            self.userReferences = []
        }
        if let refs = try container.decodeIfPresent([RawNamedReference].self, forKey: .systemReferences) {
            self.systemReferences = refs
        }
        else {
            self.systemReferences = []
        }
        if let lists = try container.decodeIfPresent([RawNamedList].self, forKey: .userLists) {
            self.userLists = lists
        }
        else {
            self.userLists = []
        }
        if let lists = try container.decodeIfPresent([RawNamedList].self, forKey: .systemLists) {
            self.systemLists = lists
        }
        else {
            self.systemLists = []
        }

        // Old versions/Compatibility
        // --------------------------------
        if let collections = try container.decodeIfPresent([String].self, forKey: ._collections) {
            self._compatibility["collections"] = collections
        }
    }
    
}

public struct RawStructure: Equatable {
    public var type: String? = nil
    public var references: [RawObjectID] = []

    public init(_ structure: Structure) {
        switch structure {
        case .unstructured: self.type = "unstructured"
        case .node: self.type = "node"
        case .edge(let origin, let target):
            self.type = "edge"
            self.references = [.id(origin), .id(target)]
        case .orderedSet(let owner, let items):
            self.type = "ordered_set"
            self.references = [.id(owner)] + items.map { .id($0) }
        }
    }
    public init(_ type: String? = nil, references: [RawObjectID] = []) {
        self.type = type
        self.references = references
    }
}

public class RawSnapshot: Codable {
    public var typeName: String?
    public var snapshotID: RawObjectID?
    public var id: RawObjectID?
    public var structure: RawStructure
    // Must be ObjectID convertible
    public var parent: RawObjectID?
    public var attributes: [String:Variant]
    
    enum CodingKeys: String, CodingKey {
        case typeName = "type"
        case structure
        case id
        case snapshotID = "snapshot_id"
        case parent
        case attributes
        // Structure keys
        case origin
        case target
        // case owner
        // case orderedSet = "ordered_set"
    }

    public init(typeName: String? = nil,
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
    public init(_ snapshot: DesignObject) {
        self.typeName = snapshot.type.name
        self.snapshotID = .id(snapshot.snapshotID)
        self.id = .id(snapshot.id)
        self.parent = snapshot.parent.map { .id($0) }
        self.attributes = snapshot.attributes
        switch snapshot.structure {
        case .unstructured:
            self.structure = RawStructure("unstructured")
        case .node:
            self.structure = RawStructure("node")
        case let .edge(origin, target):
            self.structure = RawStructure("edge", references: [.id(origin), .id(target)])
        case let .orderedSet(owner, ids):
            let allRefs: [RawObjectID] = [.id(owner)] + ids.map { .id($0) }
            self.structure = RawStructure("edge", references: allRefs)
        }
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys)
        
        self.typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
        self.id = try container.decodeIfPresent(RawObjectID.self, forKey: .id)
        self.snapshotID = try container.decodeIfPresent(RawObjectID.self, forKey: .snapshotID)
        self.parent = try container.decodeIfPresent(RawObjectID.self, forKey: .parent)
        let structureType = try container.decodeIfPresent(String.self, forKey: .structure)
        
        switch structureType {
        case .none:
            // Compatibility/legacy
            // Otherwise: Do not use origin/target without structure key.
            if let origin = try container.decodeIfPresent(RawObjectID.self, forKey: .origin),
               let target = try container.decodeIfPresent(RawObjectID.self, forKey: .target) {
                self.structure = RawStructure("edge", references: [origin, target])
            }
            else {
                self.structure = RawStructure(nil)
            }
        case "unstructured": self.structure = RawStructure(structureType)
        case "node": self.structure = RawStructure(structureType)
        case "edge":
            let origin = try container.decode(RawObjectID.self, forKey: .origin)
            let target = try container.decode(RawObjectID.self, forKey: .target)
            self.structure = RawStructure(structureType, references: [origin, target])
        default:
            self.structure = RawStructure(structureType)
        }
        
        if let attributes = try container.decodeIfPresent([String:Variant].self, forKey: .attributes) {
            self.attributes = attributes
        }
        else {
            self.attributes = [:]
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys)
        try container.encodeIfPresent(typeName, forKey: .typeName)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(snapshotID, forKey: .snapshotID)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(attributes, forKey: .attributes)
        try container.encodeIfPresent(structure.type, forKey: .structure)
        switch structure.type {
        case "edge":
            guard structure.references.count == 2 else {
                break
            }
            try container.encodeIfPresent(structure.references[0], forKey: .origin)
            try container.encodeIfPresent(structure.references[1], forKey: .target)
        default:
            break
        }
    }

    subscript(key: String) -> Variant? {
        return attributes[key]
    }
}

public class RawFrame: Codable {
    public var id: RawObjectID? = nil
    // TODO: Rename to snapshots
    public var snapshots: [RawObjectID] = []
    public init(id: RawObjectID? = nil, snapshots: [RawObjectID] = []) {
        self.id = id
        self.snapshots = snapshots
    }
}

