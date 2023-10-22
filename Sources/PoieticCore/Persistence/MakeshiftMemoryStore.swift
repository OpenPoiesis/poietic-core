//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 20/10/2023.
//

import Foundation

public enum MemoryArchiveError: Error {
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
/// - `NAME_components` - collection of components NAME, requires `SnapshotID`
/// - `frames`
///     - `id` - frame ID
///     - `snapshots` - list of snapshot IDs
///
public class MakeshiftMemoryStore {
    static let FramesCollectionName = "frames"
    static let SnapshotsCollectionName = "snapshots"
    static let MemoryStateCollectionName = "memory"
    static let ComponentCollectionSuffix = "_component"
    
    public let url :URL
    public var collections: [String:[ForeignRecord]]
    
    public init(url: URL) throws {
        self.url = url
        self.collections = [:]
    }
    
    public func load() throws {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: url)
        let archive = try decoder.decode(MakeshiftMemoryArchive.self, from: data)
        self.collections = archive.collections
    }
    
    public func save() throws {
        let archive = MakeshiftMemoryArchive(
            collections: collections
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(archive)
        try data.write(to: url)
    }

    // MARK: Schema
    var componentNames: [String] {
        collections.keys.filter { $0.hasSuffix(MakeshiftMemoryStore.ComponentCollectionSuffix) }
            .map { String($0.dropLast(MakeshiftMemoryStore.ComponentCollectionSuffix.count)) }
    }
    public func fetchAll(_ collectionName: String) throws -> [ForeignRecord] {
        guard let collection = collections[collectionName] else {
            fatalError("Unknown collection in store: \(collectionName)")
        }
        return collection
    }
    
    public func fetch(_ collectionName: String, snapshotID: ObjectID) throws -> ForeignRecord? {
        let collection = collections[collectionName]!
        return try collection.first {
            try $0["snapshotID"]?.idValue() == snapshotID
        }
    }
    
    public func replaceAll(in collectionName: String, records: [ForeignRecord]) throws {
        collections[collectionName] = records
    }
}

