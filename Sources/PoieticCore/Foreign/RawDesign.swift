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

public class RawDesign {
    var metamodelName: String? = nil
    var metamodelVersion: SemanticVersion? = nil
    var snapshots: [RawSnapshot] = []
    var frames: [RawFrame] = []

    var userReferences: [RawNamedReference] = []
    var userLists: [RawNamedList] = []

    /// Known system references:
    /// - `"current_frame"`, `"frame"`
    /// - `"application_settings"`, `"frame"`
    /// - `"design_info"`, `"object"`
    /// - `"diagram_settings"`, `"object"`
    var systemReferences: [RawNamedReference] = []

    /// Known system lists:
    /// - `"undo"`, `"frame"`
    /// - `"redo"`, `"frame`
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
