//
//  FrameReader.swift
//
//
//  Created by Stefan Urbanek on 14/08/2023.
//

import Foundation

public enum FrameReaderError: Error, CustomStringConvertible, Equatable {
    case dataCorrupted
    case propertyNotFound(String) 
    case objectPropertyNotFound(String, Int)
    case typeMismatch([String])
    
    case unknownObjectType(String, Int)
    case invalidObjectReference(String, String, Int)
    case invalidStructuralKeyPresent(String, StructuralType, Int)
    
    public var description: String {
        switch self {
        case .dataCorrupted: return "Corrupted or invalid data"
        case .propertyNotFound(let key): return "Required property '\(key)' not found"
        case .objectPropertyNotFound(let key, let index):
            return "Required property '\(key)' not found in object at index \(index)"
        case .typeMismatch(let path):
            let pathStr: String
            if path.isEmpty {
                pathStr = "the top level"
            }
            else {
                pathStr = "'" + path.joined(separator: ".") + "'"
            }
            return "Type mismatch at \(pathStr)"
        case .unknownObjectType(let type, let index):
            return "Unknown object type '\(type)' for object at index \(index)"
        case let .invalidObjectReference(ref, kind, index):
            return "Invalid \(kind) object reference '\(ref)' in object at index \(index)"
        case let .invalidStructuralKeyPresent(key, type, index):
            return "Invalid key '\(key)' present for object of structural type \(type) in object at index \(index)"
        }
    }
}


public struct ForeignFrameInfo: Codable {
    // FIXME: [IMPORTANT] This is not quite version change tolerant yet. It MUST be.
    // TODO: Allow objects to be embedded
    public let frameFormatVersion: String
    public let metadata: [String:ForeignValue]?
    public let collections: [String]?
}

public class ForeignFrameBundle {
    public let url: URL
    public let info: ForeignFrameInfo
    public var collectionNames: [String] {
        info.collections ?? ["objects"]
    }
    
    public init(url: URL) throws {
        self.url = url
        let infoURL = url.appending(component: "info.json", directoryHint: .notDirectory)

        let data = try Data(contentsOf: infoURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            info = try decoder.decode(ForeignFrameInfo.self, from: data)
        }
        catch DecodingError.dataCorrupted {
            throw FrameReaderError.dataCorrupted
        }
        catch DecodingError.keyNotFound(let key, _) {
            throw FrameReaderError.propertyNotFound(key.stringValue)
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let objects: [ForeignObject]
        
        do {
            objects = try decoder.decode(Array<ForeignObject>.self, from: data)
        }
        catch DecodingError.typeMismatch(_, let context) {
            let path = context.codingPath.map { $0.stringValue }
            throw FrameReaderError.typeMismatch(path)
        }
        catch DecodingError.keyNotFound(let codingKey, let context) {
            let key = codingKey.stringValue
            if context.codingPath.count == 1 {
                // We are always getting an int index, since this is an array and is not empty
                let index = context.codingPath[0].intValue!
                throw FrameReaderError.objectPropertyNotFound(key, index)
            }
            else {
                // Just a generic key not found, a bit hopeless but better than nothing
                throw FrameReaderError.propertyNotFound(key)
            }
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
    public var metamodel: Metamodel.Type { memory.metamodel }

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
        let decoder = JSONDecoder()
        let info: ForeignFrameInfo
        do {
            info = try decoder.decode(ForeignFrameInfo.self, from: data)
        }
        catch DecodingError.dataCorrupted {
            throw FrameReaderError.dataCorrupted
        }
        catch DecodingError.keyNotFound(let key, _) {
            throw FrameReaderError.propertyNotFound(key.stringValue)
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
        // TODO: Remove this code in favour of ForeignFrameBundle objects(in:)
        let decoder = JSONDecoder()
        let objects: [ForeignObject]
       
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            objects = try decoder.decode(Array<ForeignObject>.self, from: data)
        }
        catch DecodingError.typeMismatch(_, let context) {
            let path = context.codingPath.map { $0.stringValue }
            throw FrameReaderError.typeMismatch(path)
        }
        catch DecodingError.keyNotFound(let codingKey, let context) {
            let key = codingKey.stringValue
            if context.codingPath.count == 1 {
                // We are always getting an int index, since this is an array and is not empty
                let index = context.codingPath[0].intValue!
                throw FrameReaderError.objectPropertyNotFound(key, index)
            }
            else {
                // Just a generic key not found, a bit hopeless but better than nothing
                throw FrameReaderError.propertyNotFound(key)
            }
        }
        try read(objects, into: frame)
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
    public func read(_ objects: [ForeignObject], into frame: MutableFrame) throws {
        var snapshots: [ObjectSnapshot] = []
        // 1. Instantiate objects and gather IDs
        //
        for (index, object) in objects.enumerated() {
            
            guard let type = metamodel.objectType(name: object.type) else {
                throw FrameReaderError.unknownObjectType(object.type, index)
            }
            
            let snapshot = memory.allocateUnstructuredSnapshot(type)
            
            if let name = object.name {
                snapshot[NameComponent.self] = NameComponent(name: name)
                references[name] = snapshot.id
            }
            snapshots.append(snapshot)
        }

        // 2. Prepare the snapshot's structure
        for (index, (snapshot, object)) in zip(snapshots, objects).enumerated() {
            let structure: StructuralComponent
            let type = snapshot.type
            
            switch type.structuralType {
            case .unstructured:
                guard object.origin == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("from", type.structuralType, index)
                }
                guard object.target == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("to", type.structuralType, index)
                }

                structure = .unstructured

            case .node:
                guard object.origin == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("from", type.structuralType, index)
                }
                guard object.target == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("to", type.structuralType, index)
                }

                structure = .node

            case .edge:
                // First check the properties - makes tests easier
                guard let originRef = object.origin else {
                    throw FrameReaderError.objectPropertyNotFound("from", index)
                }
                guard let targetRef = object.target else {
                    throw FrameReaderError.objectPropertyNotFound("to", index)
                }

                guard let originID = references[originRef] else {
                    throw FrameReaderError.invalidObjectReference(originRef, "origin", index)
                }
                guard let targetID = references[targetRef] else {
                    throw FrameReaderError.invalidObjectReference(targetRef, "target", index)
                }

                structure = .edge(originID, targetID)
            }
            
            let attributes = object.attributes ?? ForeignRecord([:])
            try snapshot.initialize(structure: structure, record: attributes)
            
            frame.unsafeInsert(snapshot, owned: true)
        }
        
        // 3. Make parent-child hierarchy
        //
        // All objects are initialised now.
        // TODO: Do not use addChild, do it in unsafe way, we are ok here.
        for (index, (snapshot, object)) in zip(snapshots, objects).enumerated() {
            guard let children = object.children else {
                continue
            }
            for childRef in children {
                guard let childID = references[childRef] else {
                    throw FrameReaderError.invalidObjectReference(childRef, "child", index)
                }
                frame.addChild(childID, to: snapshot.id)
            }
        }
    }
}

