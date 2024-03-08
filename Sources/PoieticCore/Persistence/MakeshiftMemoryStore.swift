//
//  File.swift
//
//
//  Created by Stefan Urbanek on 20/10/2023.
//

import Foundation


public enum MemoryStoreError: Error, CustomStringConvertible {
    // Archive read/write
    case cannotOpenStore(URL)
    case malformedArchiveData(Error)
    case malformedArchiveStructure(String)
    case missingFormatVersion
    case unsupportedFormatVersion(String)
    case malformedCollections
    case malformedCollection(String)
    case malformedCollectionRecord(String, Int)

    case attributesNotADictionary(String, Int)
    
    case cannotCreateArchiveData(Error)
    case cannotWriteToStore(Error)
    
    // Metamodel errors
    case unknownCollection(String)
    case unknownComponentType(String)
    case unknownObjectType(String)

    /// Generic integrity error.
    ///
    /// This error should be rare and usually means that the store was
    /// modified by a third-party.
    ///
    case brokenIntegrity(String)
    case missingOrMalformedStateInfo


    /// Referenced snapshot does not exist.
    ///
    /// This is an integrity error.
    ///
    case invalidReferences(String, String)
    case invalidReference(ObjectID, String, String)
    case missingReference(String, String)
    case duplicateSnapshot(ObjectID)

    public var description: String {
        switch self {
        case let .cannotOpenStore(url):
            "Can not open archive '\(url)'"
        case let .malformedArchiveData(error):
            "Malformed archive data: \(error)"
        case let .malformedArchiveStructure(message):
            "Malformed archive structure: \(message)"
        case let .cannotCreateArchiveData(error):
            "Can not create archive data: \(error)"
        case let .cannotWriteToStore(error):
            "Can not write archive: \(error)"

        case .missingOrMalformedStateInfo:
            "Missing or malformed memory state info"

        // Model and metamodel errors
        case let .unknownCollection(name):
            "Unknown collection '\(name)'"
        case let .unknownComponentType(name):
            "Unknown component type '\(name)'"
        case let .unknownObjectType(name):
            "Unknown object type '\(name)'"

        // Integrity errors
        case let .duplicateSnapshot(id):
            "Duplicate snapshot \(id)"
        case let .brokenIntegrity(message):
            "Broken store integrity: \(message)"
        case let .invalidReferences(kind, context):
            "Invalid \(kind) references in \(context)"
        case let .invalidReference(id, kind, context):
            "Unknown \(kind) ID \(id) in \(context)"
        case let .missingReference(type, context):
            "Missing \(type) ID in \(context)"
        case .missingFormatVersion:
            "Missing store format version 'store_format_version'"
        case .unsupportedFormatVersion(let value):
            "Unsupported store format version '\(value)'"
        case .malformedCollections:
            "Malformed collections – not a dictionary."
        case .malformedCollection(let name):
            "Malformed collection '\(name)' – not an array"
        case .malformedCollectionRecord(let name, let index):
            "Malformed record \(index) in collection '\(name)'"
        case .attributesNotADictionary(let name, let index):
            "Attributes property of record \(index) in collection '\(name)' is not a dictionary"
        }
    }
}
// FIXME: [RELEASE] [IMPORTANT] Rename to ForeignObject, replace ForeignObject
public struct ObjectRecord {
    public let info: ForeignRecord
    public let attributes: ForeignRecord
    
    public init(info: ForeignRecord, attributes: ForeignRecord) {
        self.info = info
        self.attributes = attributes
    }
    
    public init(json: JSONValue) throws {
        guard case var .object(object) = json else {
            throw ForeignValueError.expectedDictionary
        }
        
        let attributes: [String:JSONValue]
        
        if let jsonAttributes = object["attributes"] {
            guard case let .object(dict) = jsonAttributes else {
                throw ForeignValueError.invalidAttributesStructure
            }
            attributes = dict
            object["attributes"] = nil
        }
        else {
            attributes = [:]
        }
        self.info = try ForeignRecord(object)
        self.attributes = try ForeignRecord(attributes)
    }
    
    /// Return a JSON representation of the object where the attributes
    /// are embedded in the top-level structure under the key `attributes`.
    ///
    public func asJSON() -> JSONValue {
        guard case var .object(record) = info.asJSON() else {
            fatalError("ForeignRecord was not converted to JSON object")
        }
        record["attributes"] = attributes.asJSON()
        return .object(record)
    }
}

/// A persistent store with relational-like traits for object memory.
///
/// Collections:
/// - `memory` – one-record collection
///      - `current_frame`
///      - `undo_frames`
///      - `redo_frames`
/// - `snapshots` - list of object snapshots
/// - `frames`
///     - `id` - frame ID
///     - `snapshots` - list of snapshot IDs
///
public class MakeshiftMemoryStore {
    static let FormatVersion = "0.0.3"
    
    static let FramesCollectionName = "frames"
    static let SnapshotsCollectionName = "snapshots"
    static let MemoryStateCollectionName = "memory"
    
    public let url :URL
    public var collections: [String:[ForeignRecord]]
    // Stored as "snapshots" collection where the attributes is embedded
    // dictionary.
    public var objects: [ObjectRecord]

    public init(url: URL) throws {
        self.url = url
        self.collections = [:]
        self.objects = []
    }
    
    public func load() throws {
        let decoder = JSONDecoder()
        let data: Data
        do {
            data = try Data(contentsOf: url)
        }
        catch {
            throw MemoryStoreError.cannotOpenStore(url)
        }
       
        let json: JSONValue
        do {
            json = try decoder.decode(JSONValue.self, from: data)
        }
        catch {
            throw MemoryStoreError.malformedArchiveData(error)
        }

        guard case let .object(root) = json else {
            throw MemoryStoreError.malformedArchiveStructure("not a dictionary")
        }
        
        guard case let .string(version) = root["store_format_version"] else {
            throw MemoryStoreError.missingFormatVersion
        }
        
        // TODO: Handle different versions here
        if version != MakeshiftMemoryStore.FormatVersion {
            throw MemoryStoreError.unsupportedFormatVersion(version)
        }
        
        guard case let .object(collections) = root["collections"] else {
            throw MemoryStoreError.malformedCollections
        }

        for (name, json) in collections {
            guard case let .array(records) = json else {
                throw MemoryStoreError.malformedCollection(name)
            }
            if name == Self.SnapshotsCollectionName {
                print("--- load objects")
                try loadObjects(records: records)
            }
            else {
                print("--- load snapshots: \(name)")
                try loadCollection(name: name, records: records)
            }
        }
        
    }
    
    func loadCollection(name: String, records jsonRecords: [JSONValue]) throws {
        var records: [ForeignRecord] = []
        for (index, json) in jsonRecords.enumerated() {
            guard case let .object(object) = json else {
                throw MemoryStoreError.malformedCollectionRecord(name, index)
            }
            
            let record = try ForeignRecord(object)
            records.append(record)
        }
        collections[name] = records
    }

    func loadObjects(records jsonRecords: [JSONValue]) throws {
        var records: [ObjectRecord] = []
        for (index, json) in jsonRecords.enumerated() {
            guard case var .object(object) = json else {
                throw MemoryStoreError.malformedCollectionRecord("snapshots", index)
            }
            
            let attributes: [String:JSONValue]
            
            if let jsonAttributes = object["attributes"] {
                guard case let .object(dict) = jsonAttributes else {
                    throw MemoryStoreError.attributesNotADictionary("snapshots", index)
                }
                attributes = dict
                object["attributes"] = nil
            }
            else {
                attributes = [:]
            }
            let record = ObjectRecord(info: try ForeignRecord(object),
                                      attributes: try ForeignRecord(attributes))
            records.append(record)
        }
        objects = records
    }

    public func save() throws {
        var root: [String:JSONValue] = [:]
        
        root["store_format_version"] = .string(MakeshiftMemoryStore.FormatVersion)

        var jsonCollections: [String:JSONValue] = [:]
        
        for (name, records) in collections {
            let jsonRecords: [JSONValue] = records.map {
                $0.asJSON()
            }
            jsonCollections[name] = .array(jsonRecords)
        }
        
        var jsonObjects: [JSONValue] = []

        for object in objects {
            jsonObjects.append(object.asJSON())
        }
        
        jsonCollections[Self.SnapshotsCollectionName] = .array(jsonObjects)
        root["collections"] = .object(jsonCollections)
        
        let jsonRoot:JSONValue = .object(root)
        
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(jsonRoot)
        }
        catch {
            throw MemoryStoreError.cannotCreateArchiveData(error)
        }
        do {
            try data.write(to: url)
        }
        catch {
            throw MemoryStoreError.cannotWriteToStore(error)
        }
    }

    // MARK: Schema
    public func fetchAllObjects() throws -> [ObjectRecord] {
        return objects
    }
    
    public func replaceAllObjects(_ objects: [ObjectRecord]) throws {
        self.objects = objects
    }

    public func fetchAll(_ collectionName: String) throws -> [ForeignRecord] {
        guard let collection = collections[collectionName] else {
            throw MemoryStoreError.unknownCollection(collectionName)
        }
        return collection
    }

    public func replaceAll(in collectionName: String, records: [ForeignRecord]) throws {
        collections[collectionName] = records
    }
}

