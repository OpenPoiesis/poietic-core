//
//  JSONForeignObject.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 22/10/2024.
//

import Foundation


/// Helper structure to convert objects to and from JSON using coding.
///
/// This structure is just a helper to have better control over JSON using
/// the built-in `Codable` protocol.
///
public struct JSONForeignObject: Encodable, DecodableWithConfiguration, ForeignObject {

    public let systemAttributes: [String:String]
    public let attributes: [String:Variant]

    public var id: String? { systemAttributes["id"] }
    public var snapshotID: String?  { systemAttributes["snapshot_id"] }
    public var name: String?  { systemAttributes["name"] }
    public var type: String?  { systemAttributes["type"] }
    public var origin: String?  { systemAttributes["from"] }
    public var target: String?  { systemAttributes["to"] }
    public var parent: String?  { systemAttributes["parent"] }
    public var structuralType: StructuralType?  {
        if let type = systemAttributes["structure"] {
            StructuralType(rawValue: type)
        }
        else {
            nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        // Note: When adding a system (string) attribute, add it to the list `system` below
        case id
        case snapshotID = "snapshot_id"
        case name
        case type
        case structure
        case origin = "from"
        case target = "to"
        // case subject // from proxy
        case parent
        case attributes
        
        static var systemKeys: [CodingKeys] {
            [.id, .snapshotID, .name, .type, .structure,
            .origin, .target,
            .parent]
        }
    }
   
    public init(_ object: DesignObject) {
        var systemAttributes: [String:String] = [:]

        systemAttributes["id"] = String(object.id)
        systemAttributes["snapshot_id"] = String(object.snapshotID)
        systemAttributes["type"] = object.type.name

        if case let .edge(origin, target) = object.structure {
            systemAttributes["from"] = String(origin)
            systemAttributes["to"] = String(target)
        }

        if let parent = object.parent {
            systemAttributes["parent"] = String(parent)
        }
        
        systemAttributes["structure"] = object.structure.type.rawValue
        self.systemAttributes = systemAttributes
        
        self.attributes = object.attributes
    }
    
    public init(from decoder: Decoder, configuration: JSONFrameReader.DecodingConfiguration) throws {
        var systemAttributes: [String:String] = [:]

        // switch configuration.version {
        // case "0": ...
        // default:
        //     throw ForeignFrameError.unsupportedVersion(configuration.version)
        // }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        for key in CodingKeys.systemKeys {
            if let value = try container.decodeIfPresent(String.self, forKey: key) {
                systemAttributes[key.stringValue] = value
            }
        }
        self.systemAttributes = systemAttributes
        self.attributes = try container.decodeIfPresent([String:Variant].self, forKey: .attributes) ?? [:]
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        for key in CodingKeys.systemKeys {
            if let value = systemAttributes[key.stringValue] {
                try container.encodeIfPresent(value, forKey: key)
            }
        }
        try container.encode(attributes, forKey: .attributes)
    }
}

/// Helper structure to convert frames to and from JSON using coding.
///
/// This structure is just a helper to have better control over JSON using
/// the built-in ``Codable`` protocol.
///
public struct JSONForeignFrame: ForeignFrameProtocol, Encodable, DecodableWithConfiguration {
    public typealias Object = JSONForeignObject
    
    public typealias DecodingConfiguration = JSONFrameReader.DecodingConfiguration

    public let metamodel: String?
    public let collectionNames: [String]
    public let objects: [JSONForeignObject]
    
    enum CodingKeys: String, CodingKey {
        case version = "format_version"
        // Private old version key TODO: Remove once prototypes are fixed
        case version_pre_v0 = "frame_format_version"
        case metamodel
        case collectionNames = "collections"
        case objects
    }
    
    public init(metamodel: String? = nil,
                objects: [JSONForeignObject] = [],
                collections: [String] = []) {
        self.metamodel = metamodel
        self.collectionNames = collections
        self.objects = objects
    }

    public init(from decoder: any Decoder, configuration: JSONFrameReader.DecodingConfiguration) throws {
        // if decoder.userInfo[JSONFrameReader.Version] as? String == "" {
        // }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Get the version
        if let version = try container.decodeIfPresent(String.self, forKey: .version) {
            configuration.version = version
        }
        else if let version = try container.decodeIfPresent(String.self, forKey: .version_pre_v0) {
            configuration.version = version
        }
        else {
            configuration.version = JSONFrameReader.CurrentFormatVersion
        }

        switch configuration.version {
        case "0":
            metamodel = try container.decodeIfPresent(String.self, forKey: .metamodel)
            collectionNames = try container.decodeIfPresent([String].self, forKey: .collectionNames) ?? []
            objects = try container.decodeIfPresent([JSONForeignObject].self,
                                                    forKey: .objects,
                                                    configuration: configuration) ?? []
        // case "1": ...
        default:
            throw ForeignFrameError.unsupportedVersion(configuration.version)
        }
        
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(JSONFrameReader.CurrentFormatVersion, forKey: .version)
        try container.encodeIfPresent(metamodel, forKey: .metamodel)
        if !collectionNames.isEmpty {
            try container.encodeIfPresent(collectionNames, forKey: .collectionNames)
        }
        if !objects.isEmpty {
            try container.encodeIfPresent(objects, forKey: .objects)
        }
    }
}
