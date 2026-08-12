//
//  RawDesignV0_1.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 12/08/2026.
//

// NOTE: This would be way much better with full control over parsed JSON - better diagnostics.
// NOTE: We are using Codable structs because Foundation bare JSON parsing is not flexible enough.
//       We also do not want to introduce additional library dependencies (yet).

class RawDesignV0_1: Codable, RawDesignConvertible {
    let metamodelName: String?
    let metamodelVersion: SemanticVersion?
    let snapshots: [RawSnapshotV0_1]
    let frames: [RawFrameV0_1]
    let userReferences: [RawNamedReferenceV0_1]
    let userLists: [RawNamedListV0_1]
    let systemReferences: [RawNamedReferenceV0_1]
    let systemLists: [RawNamedListV0_1]
    
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
        
        case _makeshiftStoreFormatVersion = "store_format_version"
        case _objects = "objects"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
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
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        let versionString = try container.decodeIfPresent(String.self, forKey: .formatVersion)
        
        if let versionString {
            guard let version = SemanticVersion(versionString),
                  version == SemanticVersion(0,1,0)
            else {
                throw RawDesignReaderError.unknownFormatVersion(versionString)
            }
        }
        
        self.metamodelName = try container.decodeIfPresent(String.self, forKey: .metamodelName)
        let metamodelVersionString = try container.decodeIfPresent(String.self, forKey: .metamodelVersion)
        if let metamodelVersionString, let version = SemanticVersion(metamodelVersionString) {
            self.metamodelVersion = version
        }
        else {
            self.metamodelVersion = nil
        }
        
        if let snapshots = try container.decodeIfPresent([RawSnapshotV0_1].self, forKey: .snapshots) {
            self.snapshots = snapshots
        }
        else if let snapshots = try container.decodeIfPresent([RawSnapshotV0_1].self, forKey: ._objects) {
            self.snapshots = snapshots
        }
        else {
            self.snapshots = []
        }
        if let frames = try container.decodeIfPresent([RawFrameV0_1].self, forKey: .frames) {
            self.frames = frames
        }
        else {
            self.frames = []
        }
        if let refs = try container.decodeIfPresent([RawNamedReferenceV0_1].self, forKey: .userReferences) {
            self.userReferences = refs
        }
        else {
            self.userReferences = []
        }
        if let refs = try container.decodeIfPresent([RawNamedReferenceV0_1].self, forKey: .systemReferences) {
            self.systemReferences = refs
        }
        else {
            self.systemReferences = []
        }
        if let lists = try container.decodeIfPresent([RawNamedListV0_1].self, forKey: .userLists) {
            self.userLists = lists
        }
        else {
            self.userLists = []
        }
        if let lists = try container.decodeIfPresent([RawNamedListV0_1].self, forKey: .systemLists) {
            self.systemLists = lists
        }
        else {
            self.systemLists = []
        }
    }
    
    var currentFrameID: RawEntityID? {
        return systemReferences.first { $0.name == "current_frame" }.map { $0.id }
    }

    // -- MARK: RawDesignConvertible
    
    required init(rawDesign: RawDesign) {
        self.metamodelName = rawDesign.metamodelName
        self.metamodelVersion = rawDesign.metamodelVersion
        
        self.snapshots = rawDesign.snapshots.map { RawSnapshotV0_1(fromRaw: $0) }
        self.frames = rawDesign.planes.map { RawFrameV0_1(fromRaw: $0) }

        self.userReferences = rawDesign.userReferences.map { RawNamedReferenceV0_1(fromRaw: $0)}
        self.userLists = rawDesign.userLists.map { RawNamedListV0_1(fromRaw: $0)}
        self.systemReferences = rawDesign.systemReferences.map { RawNamedReferenceV0_1(fromRaw: $0)}
        self.systemLists = rawDesign.systemLists.map { RawNamedListV0_1(fromRaw: $0)}
    }
    
    func asRawDesign() -> RawDesign {
        let snapshots: [RawSnapshot] = snapshots.map { $0.asRaw() }
        let planes: [RawPlane] = self.frames.map { $0.asRaw() }
        let userRefs: [RawNamedReference] = self.userReferences.map { $0.asRaw() }
        let userLists: [RawNamedList] = self.userLists.map { $0.asRaw() }
        let systemRefs: [RawNamedReference] = self.systemReferences.map { $0.asRaw() }
        let systemLists: [RawNamedList] = self.systemLists.map { $0.asRaw() }

        let result = RawDesign(
            metamodelName: self.metamodelName,
            metamodelVersion: self.metamodelVersion,
            snapshots: snapshots,
            planes: planes,
            userReferences: userRefs,
            userLists: userLists,
            systemReferences: systemRefs,
            systemLists: systemLists
        )
        return result
    }
    
}

class RawFrameV0_1: Codable {
    let id: RawEntityID?
    let snapshots: [RawEntityID]
    init(fromRaw rawPlane: RawPlane) {
        self.id = rawPlane.id
        self.snapshots = rawPlane.snapshots
    }
    func asRaw() -> RawPlane {
        return RawPlane(id: id, snapshots: snapshots)
    }
}

class RawSnapshotV0_1: Codable, CustomDebugStringConvertible {
    let typeName: String?
    let snapshotID: RawEntityID?
    let objectID: RawEntityID?
    let structure: RawStructureV0_1
    let parent: RawEntityID?
    let attributes: [String:Variant]
    
    enum CodingKeys: String, CodingKey {
        case typeName = "type"
        case structure
        case objectID = "object_id"
        case _objectID_v0_1_0 = "id"
        case snapshotID = "snapshot_id"
        case parent
        case attributes
        // Structure keys
        case references
        case origin
        case target
        // case owner
    }

    init(fromRaw snapshot: RawSnapshot) {
        self.typeName = snapshot.typeName
        self.snapshotID = snapshot.snapshotID
        self.objectID = snapshot.objectID
        self.structure = RawStructureV0_1(snapshot.topology.type,
                                          references: snapshot.topology.references)
        self.parent = snapshot.parent
        self.attributes = snapshot.attributes
    }
    
    var debugDescription: String {
        let typeName = self.typeName ?? "(no type)"
        let snapshotID = self.snapshotID ?? .string("(no snapshot ID)")
        let objectID = self.snapshotID ?? .string("(no object ID)")
        let parent = self.snapshotID ?? .string("(no parent ID)")
        return "RawSnapshotV0_1(typeName: \(typeName), snapshotID: \(snapshotID), objectID: \(objectID), structure: \(structure), parent: \(parent), attributes: \(attributes)"
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        
        self.typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
        self.objectID = try container.decodeIfPresent(RawEntityID.self, forKey: .objectID)
                        ?? container.decodeIfPresent(RawEntityID.self, forKey: ._objectID_v0_1_0)
        self.snapshotID = try container.decodeIfPresent(RawEntityID.self, forKey: .snapshotID)
        self.parent = try container.decodeIfPresent(RawEntityID.self, forKey: .parent)
        let structureType = try container.decodeIfPresent(String.self, forKey: .structure)
        
        switch structureType {
        case .none:
            // Compatibility/legacy
            // Otherwise: Do not use origin/target without topology key.
            if let origin = try container.decodeIfPresent(RawEntityID.self, forKey: .origin),
               let target = try container.decodeIfPresent(RawEntityID.self, forKey: .target) {
                self.structure = RawStructureV0_1("edge", references: [origin, target])
            }
            else {
                self.structure = RawStructureV0_1(nil, references: [])
            }
        case "unstructured": self.structure = RawStructureV0_1(structureType, references: [])
        case "node": self.structure = RawStructureV0_1(structureType, references: [])
        case "edge":
            let origin = try container.decode(RawEntityID.self, forKey: .origin)
            let target = try container.decode(RawEntityID.self, forKey: .target)
            self.structure = RawStructureV0_1(structureType, references: [origin, target])
        default:
            let refs = try container.decodeIfPresent([RawEntityID].self, forKey: .references)
            self.structure = RawStructureV0_1(structureType, references: refs ?? [])
        }
        
        if let attributes = try container.decodeIfPresent([String:Variant].self, forKey: .attributes) {
            self.attributes = attributes
        }
        else {
            self.attributes = [:]
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encodeIfPresent(typeName, forKey: .typeName)
        try container.encodeIfPresent(objectID, forKey: .objectID)
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
    
    func asRaw() -> RawSnapshot {
        return RawSnapshot(
            typeName: typeName,
            snapshotID: snapshotID,
            objectID: objectID,
            topology: structure.asRaw(),
            parent: parent,
            attributes: attributes
        )
    }
}

struct RawStructureV0_1: Equatable {
    let type: String?
    let references: [RawEntityID]
    
    init(_ type: String?, references: [RawEntityID]) {
        self.type = type
        self.references = references
    }
    
    func asRaw() -> RawTopology {
        return RawTopology(self.type, references: references)
    }
}

struct RawNamedReferenceV0_1: Equatable, Codable {
    let name: String
    /// Known types: `frame` -> plane, `object`
    let type: String
    let id: RawEntityID

    init(fromRaw ref: RawNamedReference) {
        self.name = switch ref.name {
        case "current_plane": "current_frame"
        default: ref.name
        }
        
        self.type = switch ref.type {
        case "plane": "frame"
        default: ref.type
        }
        self.id = ref.id
    }
    func asRaw() -> RawNamedReference {
        let name = switch self.name {
        case "current_frame": "current_plane"
        default: self.name
        }

        let type = switch self.type {
        case "frame": "plane"
        default: self.type
        }
        
        return RawNamedReference(name, type: type, id: id)
    }
}

struct RawNamedListV0_1: Equatable, Codable {
    let name: String
    /// Known types: `plane`
    let itemType: String
    let ids: [RawEntityID]

    enum CodingKeys: String, CodingKey {
        case name
        case itemType = "item_type"
        case ids
    }

    init(fromRaw list: RawNamedList) {
        self.name = list.name

        self.itemType = switch list.itemType {
        case "plane": "frame"
        default: list.itemType
        }

        self.ids = list.ids
    }
    func asRaw() -> RawNamedList {
        let type = switch self.itemType {
        case "frame": "plane"
        default: self.itemType
        }
        
        return RawNamedList(name, itemType: type, ids: ids)
    }
}
