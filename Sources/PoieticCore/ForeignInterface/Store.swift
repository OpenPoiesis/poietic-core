//
//  File.swift
//
//
//  Created by Stefan Urbanek on 09/06/2023.
//


import Foundation

enum PersistentStoreError: Error {
    case fileReadError(Error)
    case invalidJSONData(Error)
    case invalidJSONObject(String)
    case fileWriteError(Error)
}

// TODO: Use this (ported from Python prototype)
/// Type for values that can be stored in the persistent store.
///
/// It consists of types that conform to the `ValueProtocol` and of an object ID
/// or a list of object IDs.
///
/// - Note: Stores that do not have the ability to have a vector, list or array values
///    can store the list of IDs as a comma separated values. String
///    representation of ObjectID is guaranteed to be alpha-numeric.
///
/// PersistentValue = bool | int | float | str | Point | ObjectID | list[ObjectID]
typealias PersistentValue = Int


/// What needs to be stored:
///
/// - bundle information
///    - version of the format
/// - objects: list
///     - snapshot ID: string, optional for single-frame
///     - object ID: string, required
///     - object type: string, required
///     - attributes: dictionary of string:scalar, optional
///     - structural, required
/// - frames: list
///     - version ID
///
///
/// - Rules:
///     - if "frames" is not present, then all objects are from a single frame
///         - snapshot ID does not have to be present, will be assigned
/// - Validation:
///     - snapshot ID is unique
///     - object ID is unique in a frame
protocol PersistentStore {
    // TODO: Rename to relational persistent store
    /// Write a record that contains information about the stored design.
    /// The info record is expected to contain the following keys:
    ///
    /// - `version` – version of the stored format, a system value
    ///
    func writeInfoRecord(info: ForeignRecord)
    func readInfoRecord() -> ForeignRecord

    /// Replace all records in the store with the records provided.
    func replaceAll(type: String,
                    records: [ForeignRecord])
    
    /// Fetch all records in the store of given type.
    func fetchAll(type: String) -> [ForeignRecord]
    /// Return list of record type names.
    ///
    /// Naming convenience:
    ///
    /// - ``frames`` – frame object records
    /// - ``snapshots`` - object snapshot records
    /// - ``*_component`` - components
    ///
    func types() -> [String]

    func close()
}

/// Information about the store.
///
struct StoreInfo {
    let formatVersion: String
    
    init(dictionary: [String:any ValueProtocol]) {
        self.formatVersion = dictionary["format_version"]?.stringValue() ?? "0"
    }
    
    func asDictionary() -> [String:any ValueProtocol] {
        return [
            "format_version": formatVersion
        ]
    }
}

/*
 Reading:
 
 1. Read types
 2. Require 'info' type
 3. Require: 'frames', 'snapshots', 'framesets'
 
 
 snapshots (id, snap_id, type)
 TYPE (snap_id, attr1, attr2, ...)
 
 
 */

class StoreReader {
    /// Path to a file where the memory will be stored.
    let url: URL
    
    typealias RecordDictionary = [String:any ValueProtocol]
    /// Aggregate result to be written. This simple store holds it all in memory
    /// before writing it out.
    var _collections: [String:[RecordDictionary]]
    var _info: RecordDictionary
    
    /// Create a new store at given path.
    ///
    /// If `read` is true, read the data at the path.
    ///
    init(url: URL) throws {
        self.url = url
        self._collections = [:]
        self._info = [:]
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        }
        catch {
            throw PersistentStoreError.fileReadError(error)
        }
        
        let jsonObject: Any
        
        do {
            try jsonObject = JSONSerialization.jsonObject(with: data)
        }
        catch {
            throw PersistentStoreError.invalidJSONData(error)
        }
        
        guard let dict = jsonObject as? [String:Any] else {
            throw PersistentStoreError.invalidJSONObject("root")
        }
        
        guard let info = dict["info", default: [:]] as? RecordDictionary else {
            throw PersistentStoreError.invalidJSONObject("info")
        }
        
        self._info = info
        
        for (name, value) in dict {
            if name == "info" {
                continue
            }

            guard let validDict = value as? [RecordDictionary] else {
                throw PersistentStoreError.invalidJSONObject("collection \(name)")
            }
            _collections[name] = validDict
        }
    }
    
    func info() -> StoreInfo {
        return StoreInfo(dictionary: _info)
    }
    
    func fetchAll(type: String) -> [ForeignRecord] {
        var result: [ForeignRecord] = []
        
        guard let collection = _collections[type] else {
            return []
        }
        for dict in collection {
            let record = ForeignRecord(dict)
            result.append(record)
        }
        return result
    }
    func recordTypes() -> [String] {
        return Array(_collections.keys)
    }

}

class StoreWriter {
    /// Path to a file where the memory will be stored.
    let url: URL
    
    typealias RecordDictionary = [String:any ValueProtocol]
    /// Aggregate result to be written. This simple store holds it all in memory
    /// before writing it out.
    var _collections: [String:[ForeignRecord]]
    var _info: RecordDictionary
    
    /// Create a new store at given path.
    ///
    /// If `read` is true, read the data at the path.
    ///
    init(url: URL) throws {
        self.url = url
        self._collections = [:]
        self._info = [:]
    }
    
    func write() throws {
        fatalError("\(#function): Writing not implemented.")
//        var jsonObject: [String:Any] = [:]
//        
//        jsonObject["info"] = _info
//        
//        for (name, collection) in _collections {
//            var jsonCollection: [[String:Any]] = []
//            for item in collection {
//                jsonCollection.append(item.jsonDictionary())
//            }
//            jsonObject[name] = jsonCollection
//        }
//
//        // Not catching errors here. jsonObject is expected to be correct. If
//        // it is not correct, then it is a programming error that should not
//        // be handled.
//        //
//        let data: Data = try JSONSerialization.data(withJSONObject: jsonObject)
//
//        do {
//            try data.write(to: url)
//        }
//        catch {
//            throw PersistentStoreError.fileWriteError(error)
//        }
    }
    
    func setInfo(_ info: StoreInfo) {
        _info = info.asDictionary()
    }
    
    func replaceRecords(type: String, records: [ForeignRecord]) {
        _collections[type] = records
    }

}
