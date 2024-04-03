//
//  File.swift
//
//
//  Created by Stefan Urbanek on 20/10/2023.
//

import Foundation


public enum StoreError: Error, CustomStringConvertible {
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
            "Missing or malformed design state info"

        // Model and metamodel errors
        case let .unknownCollection(name):
            "Unknown collection '\(name)'"
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


/// A persistent store with relational-like traits for design.
///
/// Collections:
/// - `state` – one-record "collection" containing the design state
///      - `current_frame`
///      - `undo_frames`
///      - `redo_frames`
/// - `snapshots` - list of object snapshots
/// - `frames`
///     - `id` - frame ID
///     - `snapshots` - list of snapshot IDs
///
public class MakeshiftDesignStore {
    static let FormatVersion = "0.0.4"
    
    static let FramesCollectionName = "frames"
    static let SnapshotsCollectionName = "snapshots"
    static let StateCollectionName = "state"
    
    public let url :URL
    public var collections: [String:[ForeignRecord]]
    // Stored as "snapshots" collection where the attributes is embedded
    // dictionary.
    public var objects: [ForeignObject]

    /// Create a new makeshift store from a file stored at given URL.
    ///
    public init(url: URL) throws {
        self.url = url
        self.collections = [:]
        self.objects = []
    }
    
    /// Load all collections from the store.
    ///
    public func load() throws {
        let decoder = JSONDecoder()
        let data: Data
        do {
            data = try Data(contentsOf: url)
        }
        catch {
            throw StoreError.cannotOpenStore(url)
        }
       
        let json: JSONValue
        do {
            json = try decoder.decode(JSONValue.self, from: data)
        }
        catch {
            throw StoreError.malformedArchiveData(error)
        }

        guard case let .object(root) = json else {
            throw StoreError.malformedArchiveStructure("not a dictionary")
        }
        
        guard case let .string(version) = root["store_format_version"] else {
            throw StoreError.missingFormatVersion
        }
        
        // TODO: Handle different versions here
        if version != MakeshiftDesignStore.FormatVersion {
            throw StoreError.unsupportedFormatVersion(version)
        }
        
        guard case let .object(collections) = root["collections"] else {
            throw StoreError.malformedCollections
        }

        for (name, json) in collections {
            guard case let .array(records) = json else {
                throw StoreError.malformedCollection(name)
            }
            if name == Self.SnapshotsCollectionName {
                try loadObjects(records: records)
            }
            else {
                try loadCollection(name: name, records: records)
            }
        }
        
    }
    
    func loadCollection(name: String, records jsonRecords: [JSONValue]) throws {
        var records: [ForeignRecord] = []
        for (index, json) in jsonRecords.enumerated() {
            guard case let .object(object) = json else {
                throw StoreError.malformedCollectionRecord(name, index)
            }
            
            let record = try ForeignRecord(object)
            records.append(record)
        }
        collections[name] = records
    }

    func loadObjects(records jsonRecords: [JSONValue]) throws {
        var records: [ForeignObject] = []
        for (index, json) in jsonRecords.enumerated() {
            guard case var .object(object) = json else {
                throw StoreError.malformedCollectionRecord("snapshots", index)
            }
            
            let attributes: [String:JSONValue]
            
            if let jsonAttributes = object["attributes"] {
                guard case let .object(dict) = jsonAttributes else {
                    throw StoreError.attributesNotADictionary("snapshots", index)
                }
                attributes = dict
                object["attributes"] = nil
            }
            else {
                attributes = [:]
            }
            let record = ForeignObject(info: try ForeignRecord(object),
                                      attributes: try ForeignRecord(attributes))
            records.append(record)
        }
        objects = records
    }

    public func save() throws {
        var root: [String:JSONValue] = [:]
        
        root["store_format_version"] = .string(MakeshiftDesignStore.FormatVersion)

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
            throw StoreError.cannotCreateArchiveData(error)
        }
        do {
            try data.write(to: url)
        }
        catch {
            throw StoreError.cannotWriteToStore(error)
        }
    }

    // MARK: Schema
    public func fetchAllObjects() throws -> [ForeignObject] {
        return objects
    }
    
    public func replaceAllObjects(_ objects: [ForeignObject]) throws {
        self.objects = objects
    }

    public func fetchAll(_ collectionName: String) throws -> [ForeignRecord] {
        guard let collection = collections[collectionName] else {
            throw StoreError.unknownCollection(collectionName)
        }
        return collection
    }

    public func replaceAll(in collectionName: String, records: [ForeignRecord]) throws {
        collections[collectionName] = records
    }
}

