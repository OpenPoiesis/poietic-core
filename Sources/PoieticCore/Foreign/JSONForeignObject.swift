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
public struct JSONForeignObject: Encodable, Decodable, ForeignObject {
    public var type: String?
    public var structure: ForeignStructure?
    public var name: String?
    public var idReference: ForeignObjectReference?
    public var snapshotIDReference: ForeignObjectReference?
    public var parentReference: ForeignObjectReference?
    public let attributes: [String:Variant]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case snapshotID = "snapshot_id"
        case name
        case type
        case structure
        case origin = "from"
        case target = "to"
        case parent
        case attributes
    }
   
    public init(_ object: DesignObject) {
        idReference = .id(object.id)
        snapshotIDReference = .id(object.snapshotID)
        type = object.type.name

        switch object.structure {
        case .node: structure = .node
        case .unstructured: structure = .unstructured
        case let .edge(origin, target):
            structure = .edge(.id(origin), .id(target))
        case let .orderedSet(owner, items):
            structure = .orderedSet(.id(owner), items.map({.id($0)}))
        }
        
        if let parent = object.parent {
            parentReference = .id(parent)
        }
        
        self.attributes = object.attributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        idReference = try container.decodeIfPresent(ForeignObjectReference.self, forKey: .id)
        snapshotIDReference = try container.decodeIfPresent(ForeignObjectReference.self, forKey: .snapshotID)
        parentReference = try container.decodeIfPresent(ForeignObjectReference.self, forKey: .parent)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        
        if let name {
            // Original version had "name" in addition to "ID", now deprecated, but we read it anyway.
            if idReference == nil {
                idReference = .string(name)
            }
            else {
                throw ForeignObjectError.extraPropertyFound("name")
            }
        }
        
        let structureType = try container.decodeIfPresent(String.self, forKey: .structure)
        let origin = try container.decodeIfPresent(ForeignObjectReference.self, forKey: .origin)
        let target = try container.decodeIfPresent(ForeignObjectReference.self, forKey: .target)

        switch structureType {
        case "node":
            structure = .node
        case "unstructured":
            structure = .unstructured
        case "edge":
            guard let origin else {
                throw ForeignObjectError.propertyNotFound(CodingKeys.origin.rawValue)
            }
            guard let target else {
                throw ForeignObjectError.propertyNotFound(CodingKeys.target.rawValue)
            }
            structure = .edge(origin, target)
        case .none:
            if let origin, let target {
                structure = .edge(origin, target)
            }
            else {
                if (origin != nil && target == nil) || (origin == nil && target != nil) {
                    throw ForeignObjectError.invalidStructureType
                }
                else {
                    structure = nil
                }
            }
        default:
            throw ForeignObjectError.invalidStructureType
        }

        self.attributes = try container.decodeIfPresent([String:Variant].self, forKey: .attributes) ?? [:]
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(idReference, forKey: .id)
        switch structure {
        case .node:
            try container.encode("node", forKey: .structure)
        case .unstructured:
            try container.encode("unstructured", forKey: .structure)
        case let .edge(origin, target):
            try container.encode("edge", forKey: .structure)
            try container.encode(origin, forKey: .origin)
            try container.encode(target, forKey: .target)
        case let .orderedSet(owner, items):
            try container.encode("ordered_set", forKey: .structure)
            try container.encode(owner, forKey: .origin)
            try container.encode(items, forKey: .target)
        case .none:
            break /* unknown structure, just pass */
        }
        try container.encodeIfPresent(parentReference, forKey: .parent)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(snapshotIDReference, forKey: .snapshotID)
        try container.encode(attributes, forKey: .attributes)
    }
}

/// Helper structure to convert frames to and from JSON using coding.
///
/// This structure is just a helper to have better control over JSON using
/// the built-in `Codable` protocol.
///
public struct JSONForeignFrame: ForeignFrameProtocol, Encodable, Decodable {
    public typealias Object = JSONForeignObject
    
    public typealias DecodingConfiguration = JSONFrameReader.DecodingConfiguration

    public let metamodel: String?
    public let collectionNames: [String]
    public let objects: [JSONForeignObject]
    
    enum CodingKeys: String, CodingKey {
        case version = "format_version"
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

    public init(from decoder: any Decoder) throws {
        // if decoder.userInfo[JSONFrameReader.Version] as? String == "" {
        // }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // let version: String?
        
        do {
            _ = try container.decodeIfPresent(String.self, forKey: .version)
        }
        catch {
            throw ForeignFrameError.typeMismatch("String", ["format_version"])
        }

        metamodel = try container.decodeIfPresent(String.self, forKey: .metamodel)
        collectionNames = try container.decodeIfPresent([String].self, forKey: .collectionNames) ?? []

        do {
            let collection = try container.decodeIfPresent(_JSONForeignObjectCollection.self, forKey: .objects)
            objects = collection.map { $0.objects } ?? []
        }
        catch let error as ForeignObjectError {
            throw ForeignFrameError.foreignObjectError(error, 0)
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

/// Wrapper for better error reporting – to get index of broken objects.
struct _JSONForeignObjectCollection: Decodable {
    let objects: [JSONForeignObject]
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var objects: [JSONForeignObject] = []
        var index: Int = 0
        while !container.isAtEnd {
            do {
                let object = try container.decode(JSONForeignObject.self)
                objects.append(object)
            }
            catch let error as ForeignObjectError {
                throw ForeignFrameError.foreignObjectError(error, index)
            }
            index += 1
        }
        self.objects = objects
    }
}
