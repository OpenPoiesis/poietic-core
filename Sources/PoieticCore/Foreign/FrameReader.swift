//
//  FrameReader.swift
//
//
//  Created by Stefan Urbanek on 14/08/2023.
//

import Foundation

/// Error thrown when reading or processing a foreign frame.
///
/// - SeeAlso: ``ForeignFrameReader``, ``ForeignObjectError``
///
public enum ForeignFrameError: Error, Equatable, CustomStringConvertible {
    case dataCorrupted
    case JSONError(JSONError)
    case foreignObjectError(ForeignObjectError, Int)
    case unknownObjectType(String, Int)
    case missingFrameFormatVersion
    case invalidReference(String, String, Int)
    
    public var description: String {
        switch self {
        case .dataCorrupted:
            "Corrupted data"
        case .JSONError(let error):
            "JSON error: \(error)"
        case .foreignObjectError(let error, let index):
            "Error in object at \(index): \(error)"
        case .unknownObjectType(let type, let index):
            "Unknown object type '\(type)' for object at index \(index)"
        case .missingFrameFormatVersion:
            "Missing frame format version"
        case let .invalidReference(ref, kind, index):
            "Invalid \(kind) object reference '\(ref)' in object at index \(index)"
        }
    }
}

/// Structure holding information about a foreign frame.
///
public struct ForeignFrameInfo {
    // TODO: Allow objects to be embedded
    /// Version of the data structure in the foreign frame.
    ///
    public let frameFormatVersion: String

    /// Name of the metamodel the frame is using.
    ///
    /// - Note: It is up to the reader to decide compatibility of the foreign
    ///   frame with the metamodel of the memory that the frame is being
    ///   imported to.
    ///
    /// - SeeAlso: ``metamodelVersion``
    ///
    public let metamodelName: String?


    /// Version of the metamodel the frame is using.
    ///
    /// - Note: It is up to the reader to decide compatibility of the foreign
    ///   frame with the metamodel of the memory that the frame is being
    ///   imported to.
    ///
    /// - SeeAlso: ``metamodelName``
    ///
    public let metamodelVersion: String?
    
    /// List of names of collections to be imported.
    ///
    /// If the foreign frame is a bundle, this is a list of names of collections
    /// stored in the `objects` sub-directory of the frame bundle.
    ///
    /// - Note: See ``init(fromJSON:)`` for more information about collections
    ///   initialized from a JSON value.
    ///
    public let collectionNames: [String]?

    /// Create a foreign frame info from a JSON value.
    ///
    /// The JSON value must be a dictionary and must contain at least `frame_format_version`
    /// key.
    ///
    /// Other keys:
    ///
    /// - `metamodel_name`
    /// - `metamodel_version`
    /// - `collections`
    ///
    /// If the `collections` key is not provided, then the list of collections
    /// will contain one name `objects`.
    ///
    /// - Throws: ``JSONError`` if there is an issue with types or properties
    ///   in the provided JSON value.
    ///
    public init(fromJSON json: JSONValue) throws {
        let dict = try json.asDictionary()
        
        self.frameFormatVersion = try dict.string(forKey: "frame_format_version")
        self.metamodelName = try dict.stringIfPresent(forKey: "metamodel_name")
        self.metamodelVersion = try dict.stringIfPresent(forKey: "metamodel_version")

        if let items = try dict.arrayIfPresent(forKey: "collections"){
            var collections: [String] = []
            for item in items {
                let value = try item.asString()
                collections.append(value)
            }
            self.collectionNames = collections
        }
        else {
            self.collectionNames = ["objects"]
        }
    }
}

/// Object representing URL based foreign frame, such as a directory on a file
/// system.
///
public class ForeignFrameBundle {

    /// URL of the foreign frame bundle.
    ///
    public let url: URL


    public let info: ForeignFrameInfo
    public var collectionNames: [String] {
        info.collectionNames ?? ["objects"]
    }

    /// Create a new foreign frame bundle object at given URL.
    ///
    /// The expected objects and sub-paths are:
    /// - `info.json` – information about the bundle. See ``ForeignFrameInfo``
    ///   for more information.
    /// - `objects` sub-path with `*.json` files each representing a collection
    ///   of objects.
    ///
    /// Example foreign frame bundle structure:
    ///
    /// ```
    /// Capital.poieticframe
    ///  ├── info.json
    ///  └── objects
    ///      ├── design.json
    ///      ├── objects.json
    ///      └── report.json
    /// ```
    ///
    /// Example of corresponding `info.json`:
    ///
    /// ```json
    /// {
    ///     "frame_format_version": "2023.9",
    ///     "metamodel": "Flows",
    ///
    ///     "collections": [ "design", "objects", "report" ],
    /// }
    /// ```
    ///
    /// - Throws: ``ForeignFrameError``
    ///
    public init(url: URL) throws {
        self.url = url
        let infoURL = url.appending(component: "info.json", directoryHint: .notDirectory)

        let data = try Data(contentsOf: infoURL)

        do {
            info = try ForeignFrameInfo(fromJSON: JSONValue(data: data))
        }
        catch JSONError.dataCorrupted {
            throw ForeignFrameError.dataCorrupted
        }
        catch {
            fatalError("Unhandled error: \(error)")
        }
        // TODO: Read this from info dictionary, path or URL (github)
    }
    
    public convenience init(path: String) throws {
        try self.init(url: URL(fileURLWithPath: path, isDirectory: true))
    }

    public func urlForObjectCollection(_ name: String) -> URL {
        url.appending(components: "objects", "\(name).json", directoryHint: .notDirectory)
    }
    
    public func objects(in collectionName: String) throws -> [ForeignObject] {
        // NOTE: Sync this code with ForeignFrameReader read(data:,frame:)
        let collectionURL = urlForObjectCollection(collectionName)
        let data = try Data(contentsOf: collectionURL)

        let json = try JSONValue(data: data)
        
        let jsonArray = try json.asArray()

        var objects: [ForeignObject] = []
        for jsonItem in jsonArray {
            let object = try ForeignObject(json: jsonItem)
            objects.append(object)
        }
        
        return objects
    }
}

/// Object that reads a frame from a frame package.
///
/// Object that read an archive, typically a file, containing a single frame
/// and inserts the objects found in the archive into the memory.
///
public class ForeignFrameReader {
    public let info: ForeignFrameInfo
    public let memory: ObjectMemory
    public var metamodel: Metamodel { memory.metamodel }

    /// References to objects that already exist in the frame. The key might
    /// be either an object name or a string representation of an object ID.
    ///
    public var references: [String: ObjectID] = [:]
    
    public convenience init(path: String, memory: ObjectMemory) throws {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let data = try Data(contentsOf: url)
        try self.init(data: data, memory: memory)
    }
    
    public convenience init(data: Data, memory: ObjectMemory) throws {
        let info: ForeignFrameInfo
        do {
            info = try ForeignFrameInfo(fromJSON: JSONValue(data: data))
        }
        catch let error as JSONError {
            switch error {
            case .propertyNotFound(let name):
                if name == "frame_format_version" {
                    throw ForeignFrameError.missingFrameFormatVersion
                }
                else {
                    // This should not happen, just in case
                    throw ForeignFrameError.JSONError(error)
                }
            default:
                throw ForeignFrameError.JSONError(error)
            }
        }
        catch {
            fatalError("Unhandled error: \(error)")
        }
        self.init(info: info, memory: memory)
    }
    
    /// Create a new frame reader with given reader info data.
    ///
    /// The data must contain a JSON dictionary structure.
    ///
    public init(info: ForeignFrameInfo , memory: ObjectMemory) {
        self.info = info
        self.memory = memory
    }

    
    /// Incrementally read frame data into a mutable frame.
    ///
    /// Data is a JSON encoded array of foreign object descriptions.
    ///
    /// See ``ForeignFrameReader/read(_:into:)-65epr`` for more information.
    ///
    /// - Note: This function is non-transactional. The frame is assumed to
    ///         represent a transaction. When the function fails, the whole
    ///         frame should be discarded.
    ///
    public func read(_ data: Data, into frame: MutableFrame) throws {
        let jsonObjects: [JSONValue]
        do {
            jsonObjects = try JSONValue(data: data).asArray()
        }
        catch let error as JSONError {
            throw ForeignFrameError.JSONError(error)

        }

        var foreignObjects: [ForeignObject] = []
        
        for jsonObject in jsonObjects {
            let foreignObject = try ForeignObject(json: jsonObject)
            foreignObjects.append(foreignObject)
        }
        
        try read(foreignObjects, into: frame)
    }
   
    /// Incrementally read frame data into a mutable frame.
    ///
    /// For each object in the collection, in the order as provided:
    ///
    /// 1. get a concrete object type instance from the frame's memory metamodel
    /// 2. create an object snapshot in the frame using the given object type
    ///    and a foreign record representing the attributes. The structure
    ///    is not yet set-up.
    ///
    /// When all the objects are instantiated and inserted in the frame, then
    /// for each object:
    ///
    /// 1. Graph structure is created
    /// 2. Hierarchical parent-child structure is created.
    ///
    /// Object references used can be either object names or object IDs.
    ///
    /// Requirements:
    ///
    /// - Object references must be valid from within the collection of objects
    ///   provided or from within previous collections read.
    ///   Otherwise ``FrameReaderError/invalidObjectReference(_:_:_:)``
    ///   is thrown on the first invalid reference.
    /// - Edges must have both origin and target specified, otherwise
    ///   ``FrameReaderError/objectPropertyNotFound(_:_:)`` is thrown.
    /// - Other structural types must not have neither origin neither target
    ///   specified, if they do then ``FrameReaderError/invalidStructuralKeyPresent(_:_:_:)``
    ///   is thrown.
    ///
    /// - Note: This function is non-transactional. The frame is assumed to
    ///         represent a transaction. When the function fails, the whole
    ///         frame should be discarded.
    /// - Throws: ``FrameReaderError``
    /// - SeeAlso: ``ObjectMemory/allocateUnstructuredSnapshot(_:id:snapshotID:)``,
    ///     ``MutableFraminsert(_:owned:):)``
    ///
    public func read(_ foreignObjects: [ForeignObject], into frame: MutableFrame) throws {
        var snapshots: [ObjectSnapshot] = []
        
        var ids: [ObjectID] = []
        var snapshotIDs: [ObjectID] = []
        
        // 1. Allocate identities and collect references
        for foreignObject in foreignObjects {
            // TODO: Catch foreign object error and wrap it with more info
            let actualID: ObjectID
            if let stringID = try foreignObject.id {
                actualID = memory.allocateID(required: ObjectID(stringID))
            }
            else {
                actualID = memory.allocateID()
            }

            ids.append(actualID)

            let actualSnapshotID: ObjectID
            if let stringID = try foreignObject.id {
                actualSnapshotID = memory.allocateID(required: ObjectID(stringID))
            }
            else {
                actualSnapshotID = memory.allocateID()
            }
            snapshotIDs.append(actualSnapshotID)

            if let name = try foreignObject.name {
                references[name] = actualID
            }
        }
        
        // 2. Instantiate objects
        //
        for (index, foreignObject) in foreignObjects.enumerated() {
            let id = ids[index]
            let snapshotID = snapshotIDs[index]
            
            let structure: StructuralComponent
            
            guard let typeName = try foreignObject.type else {
                throw ForeignFrameError.foreignObjectError(.missingObjectType, index)
            }
            
            guard let type = metamodel.objectType(name: typeName) else {
                throw ForeignFrameError.unknownObjectType(typeName, index)
            }
            
            switch type.structuralType {
            case .unstructured:
                guard try foreignObject.origin == nil else {
                    throw ForeignFrameError.foreignObjectError(.extraPropertyFound("from"), index)
                }
                guard try foreignObject.target == nil else {
                    throw ForeignFrameError.foreignObjectError(.extraPropertyFound("to"), index)
                }

                structure = .unstructured

            case .node:
                guard try foreignObject.origin == nil else {
                    throw ForeignFrameError.foreignObjectError(.extraPropertyFound("from"), index)
                }
                guard try foreignObject.target == nil else {
                    throw ForeignFrameError.foreignObjectError(.extraPropertyFound("to"), index)
                }
                structure = .node

            case .edge:
                // First check the properties - makes tests easier
                guard let originRef = try foreignObject.origin else {
                    throw ForeignFrameError.foreignObjectError(.propertyNotFound("from"), index)
                }
                guard let targetRef = try foreignObject.target else {
                    throw ForeignFrameError.foreignObjectError(.propertyNotFound("to"), index)
                }

                guard let originID = references[originRef] else {
                    throw ForeignFrameError.invalidReference(originRef, "origin", index)
                }
                guard let targetID = references[targetRef] else {
                    throw ForeignFrameError.invalidReference(targetRef, "target", index)
                }

                structure = .edge(originID, targetID)
            }
            let snapshot = memory.createSnapshot(type,
                                                 id: id,
                                                 snapshotID: snapshotID,
                                                 structure: structure,
                                                 state: .transient)
            
            if let name = try foreignObject.name {
                snapshot.setAttribute(value: Variant(name), forKey: "name")
                references[name] = snapshot.id
            }
            
            for (key, value) in foreignObject.attributes {
                snapshot.setAttribute(value: value, forKey: key)
            }
            
            snapshots.append(snapshot)
            snapshot.promote(.stable)
            frame.unsafeInsert(snapshot, owned: true)
        }

        // 3. Make parent-child hierarchy
        //
        // All objects are initialised now.
        // TODO: Do not use addChild, do it in unsafe way, we are ok here.
        for (index, (snapshot, object)) in zip(snapshots, foreignObjects).enumerated() {
            guard let children = try object.children else {
                continue
            }
            for childRef in children {
                guard let childID = references[childRef] else {
                    throw ForeignFrameError.invalidReference(childRef, "child", index)
                }
                frame.addChild(childID, to: snapshot.id)
            }
        }
    }
}

