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
        }
    }
}

private struct MakeshiftMemoryArchive: Codable {
    var formatVersion: String = "0.0.2"
    var collections: [String:[ForeignRecord]] = [:]
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
    static let FramesCollectionName = "frames"
    static let SnapshotsCollectionName = "snapshots"
    static let MemoryStateCollectionName = "memory"
    // TODO: Use for persisted components (no longer used for attributes)
    static let ComponentCollectionSuffix = "_component"
    
    public let url :URL
    public var collections: [String:[ForeignRecord]]
    
    public init(url: URL) throws {
        self.url = url
        self.collections = [:]
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
        
        let archive: MakeshiftMemoryArchive
        do {
            archive = try decoder.decode(MakeshiftMemoryArchive.self, from: data)
        }
        catch {
            throw MemoryStoreError.malformedArchiveData(error)
        }
        self.collections = archive.collections
    }
    
    public func save() throws {
        let archive = MakeshiftMemoryArchive(
            collections: collections
        )
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(archive)
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
    var componentNames: [String] {
        collections.keys.filter { $0.hasSuffix(MakeshiftMemoryStore.ComponentCollectionSuffix) }
            .map { String($0.dropLast(MakeshiftMemoryStore.ComponentCollectionSuffix.count)) }
    }
    
    public func fetchAll(_ collectionName: String) throws -> [ForeignRecord] {
        guard let collection = collections[collectionName] else {
            throw MemoryStoreError.unknownCollection(collectionName)
        }
        return collection
    }
    
    public func fetch(_ collectionName: String, snapshotID: ObjectID) throws -> ForeignRecord? {
        let collection = collections[collectionName]!
        return try collection.first {
            try $0["snapshotID"]?.stringValue() == String(snapshotID)
        }
    }
    
    public func replaceAll(in collectionName: String, records: [ForeignRecord]) throws {
        collections[collectionName] = records
    }
}

