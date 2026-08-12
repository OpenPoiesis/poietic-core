//
//  RawDesignV0_2.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 12/08/2026.
//

// NOTE: This would be way much better with full control over parsed JSON - better diagnostics.
// NOTE: We are using Codable structs because Foundation bare JSON parsing is not flexible enough.
//       We also do not want to introduce additional library dependencies (yet).

// QUESTION: should we keep origin/target as edge topology top-level for convenience?
// QUESTION: what to do with Variant.CodingTypeKey?

class RawDesignV0_2: Codable, RawDesignConvertible {
    let metamodelName: String?
    let metamodelVersion: SemanticVersion?
    let snapshots: [RawSnapshotV0_2]
    let planes: [RawPlaneV0_2]
    let userReferences: [RawNamedReferenceV0_2]
    let userLists: [RawNamedListV0_2]
    let systemReferences: [RawNamedReferenceV0_2]
    let systemLists: [RawNamedListV0_2]
    
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case metamodelName = "metamodel"
        case metamodelVersion = "metamodel_version"
        case snapshots
        case planes
        case userReferences = "user_references"
        case systemReferences = "system_references"
        case userLists = "user_lists"
        case systemLists = "system_lists"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(JSONDesignReader.CurrentFormatVersion.description, forKey: .formatVersion)
        try container.encodeIfPresent(metamodelName, forKey: .metamodelName)
        try container.encodeIfPresent(metamodelVersion?.description, forKey: .metamodelVersion)
        if !snapshots.isEmpty {
            try container.encode(snapshots, forKey: .snapshots)
        }
        if !planes.isEmpty {
            try container.encode(planes, forKey: .planes)
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
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        let versionString = try container.decodeIfPresent(String.self, forKey: .formatVersion)
        
        if let versionString {
            guard let version = SemanticVersion(versionString),
                  version == SemanticVersion(0,2,0)
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
        
        if let snapshots = try container.decodeIfPresent([RawSnapshotV0_2].self, forKey: .snapshots) {
            self.snapshots = snapshots
        }
        else {
            self.snapshots = []
        }
        if let planes = try container.decodeIfPresent([RawPlaneV0_2].self, forKey: .planes) {
            self.planes = planes
        }
        else {
            self.planes = []
        }
        if let refs = try container.decodeIfPresent([RawNamedReferenceV0_2].self, forKey: .userReferences) {
            self.userReferences = refs
        }
        else {
            self.userReferences = []
        }
        if let refs = try container.decodeIfPresent([RawNamedReferenceV0_2].self, forKey: .systemReferences) {
            self.systemReferences = refs
        }
        else {
            self.systemReferences = []
        }
        if let lists = try container.decodeIfPresent([RawNamedListV0_2].self, forKey: .userLists) {
            self.userLists = lists
        }
        else {
            self.userLists = []
        }
        if let lists = try container.decodeIfPresent([RawNamedListV0_2].self, forKey: .systemLists) {
            self.systemLists = lists
        }
        else {
            self.systemLists = []
        }
    }
    
    // -- MARK: RawDesignConvertible
    
    required init(rawDesign: RawDesign) {
        self.metamodelName = rawDesign.metamodelName
        self.metamodelVersion = rawDesign.metamodelVersion
        
        self.snapshots = rawDesign.snapshots.map { RawSnapshotV0_2(fromRaw: $0) }
        self.planes = rawDesign.planes.map { RawPlaneV0_2(fromRaw: $0) }

        self.userReferences = rawDesign.userReferences.map { RawNamedReferenceV0_2(fromRaw: $0)}
        self.userLists = rawDesign.userLists.map { RawNamedListV0_2(fromRaw: $0)}
        self.systemReferences = rawDesign.systemReferences.map { RawNamedReferenceV0_2(fromRaw: $0)}
        self.systemLists = rawDesign.systemLists.map { RawNamedListV0_2(fromRaw: $0)}
    }
    
    func asRawDesign() -> RawDesign {
        let snapshots: [RawSnapshot] = snapshots.map { $0.asRaw() }
        let planes: [RawPlane] = self.planes.map { $0.asRaw() }
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

class RawPlaneV0_2: Codable {
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

class RawSnapshotV0_2: Codable, CustomDebugStringConvertible {
    let typeName: String?
    let snapshotID: RawEntityID?
    let objectID: RawEntityID?
    let topology: RawTopologyV0_2
    let parent: RawEntityID?
    let attributes: [String:Variant]
    
    enum CodingKeys: String, CodingKey {
        case typeName = "type"
        case topology
        case references // Topology references
        case objectID = "object_id"
        case snapshotID = "snapshot_id"
        case parent
        case attributes
    }

    var debugDescription: String {
        let typeName = self.typeName ?? "(no type)"
        let snapshotID = self.snapshotID ?? .string("(no snapshot ID)")
        let objectID = self.snapshotID ?? .string("(no object ID)")
        let parent = self.snapshotID ?? .string("(no parent ID)")
        return "RawSnapshot(typeName: \(typeName), snapshotID: \(snapshotID), objectID: \(objectID), topology: \(topology), parent: \(parent), attributes: \(attributes)"
    }
    
    init(fromRaw snapshot: RawSnapshot) {
        self.typeName = snapshot.typeName
        self.snapshotID = snapshot.snapshotID
        self.objectID = snapshot.objectID
        self.parent = snapshot.parent
        self.attributes = snapshot.attributes
        self.topology = RawTopologyV0_2(fromRaw: snapshot.topology)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        
        self.typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
        self.objectID = try container.decodeIfPresent(RawEntityID.self, forKey: .objectID)
        self.snapshotID = try container.decodeIfPresent(RawEntityID.self, forKey: .snapshotID)
        self.parent = try container.decodeIfPresent(RawEntityID.self, forKey: .parent)
        let topologyType = try container.decodeIfPresent(String.self, forKey: .topology)
        let topologyRefs = try container.decodeIfPresent([RawEntityID].self, forKey: .references)
        self.topology = RawTopologyV0_2(topologyType, references: topologyRefs ?? [])

        let attributes = try container.decodeIfPresent([String:Variant].self, forKey: .attributes)
        self.attributes = attributes ?? [:]
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encodeIfPresent(typeName, forKey: .typeName)
        try container.encodeIfPresent(objectID, forKey: .objectID)
        try container.encodeIfPresent(snapshotID, forKey: .snapshotID)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(attributes, forKey: .attributes)
        try container.encodeIfPresent(topology.type, forKey: .topology)
        if !topology.references.isEmpty {
            try container.encode(topology.references, forKey: .references)
        }
    }

    func asRaw() -> RawSnapshot {
        return RawSnapshot(
            typeName: typeName,
            snapshotID: snapshotID,
            objectID: objectID,
            topology: topology.asRaw(),
            parent: parent,
            attributes: attributes
        )
    }
}

struct RawTopologyV0_2: Equatable {
    let type: String?
    let references: [RawEntityID]
    
    init(_ type: String? = nil, references: [RawEntityID] = []) {
        self.type = type
        self.references = references
    }
    
    init(fromRaw raw: RawTopology) {
        self.type = raw.type
        self.references = raw.references
    }
    
    func asRaw() -> RawTopology {
        return RawTopology(self.type, references: references)
    }
}


struct RawNamedReferenceV0_2: Equatable, Codable {
    let name: String
    let type: String
    let id: RawEntityID

    init(fromRaw ref: RawNamedReference) {
        self.name = ref.name
        self.type = ref.type
        self.id = ref.id
    }
    func asRaw() -> RawNamedReference {
        return RawNamedReference(name, type: type, id: id)
    }
}

struct RawNamedListV0_2: Equatable, Codable {
    let name: String
    let itemType: String
    let ids: [RawEntityID]

    enum CodingKeys: String, CodingKey {
        case name
        case itemType = "item_type"
        case ids
    }

    init(fromRaw list: RawNamedList) {
        self.name = list.name
        self.itemType = list.itemType
        self.ids = list.ids
    }
    func asRaw() -> RawNamedList {
        return RawNamedList(name, itemType: itemType, ids: ids)
    }
}
