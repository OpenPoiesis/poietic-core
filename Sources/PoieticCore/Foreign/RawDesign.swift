//
//  ForeignDesign.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 01/05/2025.
//

protocol RawDesignConvertible {
    /// Convert this version-specific representation to a raw design.
    func asRawDesign() -> RawDesign
    
    /// Create a version-specific representation from a raw design.
    init(rawDesign: RawDesign)
}

/// Object ID retrieved from a foreign interface.
///
/// Raw object ID is a foreign representation of Object ID that can be in one of three forms:
/// as an int, as a string or an explicit ``ObjectID``.
///
public enum RawEntityID:
    Hashable,
    Codable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible
{
    /// Native Object ID representation
    case id(DesignEntityID)
    /// Representation as an integer.
    ///
    /// Known applications that use integer representation:
    ///
    /// - Poietic Playground
    ///
    case int(Int64)
    
    /// Representation as a string.
    ///
    case string(String)
    
    public func designEntityID() -> DesignEntityID? {
        switch self {
        case .id(let value): value
        case .int(let value): DesignEntityID(intValue: UInt64(bitPattern: value))
        case .string(let value): DesignEntityID(value)
        }
    }
    
    public var description: String {
        switch self {
        case .id(let value): value.stringValue
        case .int(let value): String(value)
        case .string(let value): value
        }
    }
    
    public var debugDescription: String {
        switch self {
        case .id(let value): "RawObjectID.id(\(value))"
        case .int(let value): "RawObjectID.int(\(value))"
        case .string(let value): "RawObjectID.string(\(value))"
        }
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(DesignEntityID.self) {
            self = .id(value)
        }
        else if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        else {
            let value = try container.decode(Int64.self)
            self = .int(value)
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

extension DesignEntityID {
    init?(_ raw: RawEntityID) {
        switch raw {
        case let .id(value):
            self = value
        case let .int(rawValue: value):
            self.init(intValue: UInt64(bitPattern: value))
        case let .string(stringValue):
            self.init(stringValue)
        }
    }
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
    /// Snapshots are expected to be used by the planes. Any snapshot not used by a plane within the
    /// raw design should be discarded during loading process.
    ///
    public var snapshots: [RawSnapshot] = []

    /// List of planes.
    ///
    public var planes: [RawPlane] = []

    /// References to metamodel entities created by an user, typically through an application.
    ///
    /// For example, ``Design/namedPlanes`` are stored here as named references of type `"plane"`.
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
    /// | `current_plane` |  `plane` | ID of current plane (see ``Design/currentPlaneID``) |
    /// | `application_settings` | `plane` | ID of plane containing application settings. A non-versioned plane. |
    public var systemReferences: [RawNamedReference] = []

    /// Named lists of references created by and managed by the system.
    ///
    /// | Name | Item Type | Description |
    /// | ---- | --------- | ----------- |
    /// | `undo` | `plane` | List of undoable planes. See ``Design/undoList`` |
    /// | `redo` | `plane` | List of re-doable planes. See ``Design/redoList`` |
    ///
    public var systemLists: [RawNamedList] = []
    
    /// Create a new raw design.
    public init(metamodelName: String? = nil,
                  metamodelVersion: SemanticVersion? = nil,
                  snapshots: [RawSnapshot] = [],
                  planes: [RawPlane] = [],
                  userReferences: [RawNamedReference] = [],
                  userLists: [RawNamedList] = [],
                  systemReferences: [RawNamedReference] = [],
                  systemLists: [RawNamedList] = []) {
        self.metamodelName = metamodelName
        self.metamodelVersion = metamodelVersion
        self.snapshots = snapshots
        self.planes = planes
        self.userReferences = userReferences
        self.userLists = userLists
        self.systemReferences = systemReferences
        self.systemLists = systemLists
    }
    
    var currentPlaneID: RawEntityID? {
        return systemReferences.first { $0.name == "current_plane" }.map { $0.id }
    }
    
    func first(snapshotWithID id: RawEntityID) -> RawSnapshot? {
        return snapshots.first { $0.snapshotID == id }
    }
}

public struct RawTopology: Equatable {
    public var type: String? = nil
    public var references: [RawEntityID] = []

    public init(_ topology: Structure) {
        switch topology {
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
    public init(_ type: String? = nil, references: [RawEntityID] = []) {
        self.type = type
        self.references = references
    }
    
    /// Create a raw structure representing an edge.
    public init(origin: RawEntityID, target: RawEntityID) {
        self.type = "edge"
        self.references = [origin, target]
    }
}

/// Raw representation of a snapshot.
///
/// Raw snapshot can be freely mutated and does not have to conform to any constraints, neither
/// has to have referential integrity with other snapshots within any other raw structure, unless
/// needed to be loaded.
///
public class RawSnapshot: CustomDebugStringConvertible {
    
    /// Name of object type.
    ///
    /// Used to look-up object type in a metamodel ``Metamodel/objectType(name:)``.
    ///
    public var typeName: String?
    
    /// Raw representation of snapshot ID.
    ///
    /// If not provided, it will be typically generated.
    ///
    public var snapshotID: RawEntityID?

    /// Raw representation of snapshot ID.
    ///
    /// If not provided, it will be typically generated.
    ///
    /// If ``DesignLoader/Options-swift.struct/useIDAsNameAttribute`` option is set for a design
    /// loader, if the ID is a string and if the attributes do not contain `name` key,
    /// then the string ID value will be also used as the `name` attribute.
    ///
    public var objectID: RawEntityID?
    
    /// Raw topology representation.
    ///
    /// - Note: When raw snapshot is encoded, then the `edge` topology type will result in two
    ///   additional keys `origin` and `target` that are part of the raw topology references.
    ///
    public var topology: RawTopology
    // Must be ObjectID convertible

    /// Parent object ID.
    public var parent: RawEntityID?

    /// Dictionary of object attributes.
    ///
    /// See also note about `name` in the ``objectID`` property description.
    ///
    public var attributes: [String:Variant]
    
    /// Create a new raw snapshot.
    ///
    public init(typeName: String? = nil,
                snapshotID: RawEntityID? = nil,
                objectID: RawEntityID? = nil,
                topology: RawTopology = RawTopology(nil, references: []),
                parent: RawEntityID? = nil,
                attributes: [String:Variant] = [:])
    {
        self.typeName = typeName
        self.snapshotID = snapshotID
        self.objectID = objectID
        self.topology = topology
        self.parent = parent
        self.attributes = attributes
    }

    public var debugDescription: String {
        let typeName = self.typeName ?? "(no type)"
        let snapshotID = self.snapshotID ?? .string("(no snapshot ID)")
        let objectID = self.snapshotID ?? .string("(no object ID)")
        let parent = self.snapshotID ?? .string("(no parent ID)")
        return "RawSnapshot(typeName: \(typeName), snapshotID: \(snapshotID), objectID: \(objectID), topology: \(topology), parent: \(parent), attributes: \(attributes)"
    }
    
    /// Create a raw snapshot from a design object.
    ///
    public init(_ snapshot: ObjectSnapshot) {
        self.typeName = snapshot.type.name
        self.snapshotID = .id(snapshot.snapshotID)
        self.objectID = .id(snapshot.objectID)
        self.parent = snapshot.parent.map { .id($0) }
        self.attributes = snapshot.attributes
        switch snapshot.structure {
        case .unstructured:
            self.topology = RawTopology("unstructured")
        case .node:
            self.topology = RawTopology("node")
        case let .edge(origin, target):
            self.topology = RawTopology("edge", references: [.id(origin), .id(target)])
        case let .orderedSet(owner, ids):
            let allRefs: [RawEntityID] = [.id(owner)] + ids.map { .id($0) }
            self.topology = RawTopology("edge", references: allRefs)
        }
    }

    subscript(key: String) -> Variant? {
        return attributes[key]
    }
}

public class RawPlane {
    public var id: RawEntityID? = nil
    public var snapshots: [RawEntityID] = []
    public init(id: RawEntityID? = nil, snapshots: [RawEntityID] = []) {
        self.id = id
        self.snapshots = snapshots
    }
}

public struct RawNamedReference: Equatable {
    public let name: String
    /// Known types: `plane`, `object`
    public let type: String
    public let id: RawEntityID

    public init(_ name: String, type: String, id: RawEntityID) {
        self.name = name
        self.type = type
        self.id = id
    }
}

public struct RawNamedList: Equatable {
    public let name: String
    /// Known types: `plane`
    public let itemType: String
    public let ids: [RawEntityID]

    public init(_ name: String, itemType: String, ids: [RawEntityID]) {
        self.name = name
        self.itemType = itemType
        self.ids = ids
    }
}

