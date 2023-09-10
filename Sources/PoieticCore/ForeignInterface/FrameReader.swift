//
//  FrameReader.swift
//
//
//  Created by Stefan Urbanek on 14/08/2023.
//

// TODO: Test reading of the following wrongs:
// - present origin/target for a non-edge

import Foundation

public enum FrameReaderError: Error, CustomStringConvertible, Equatable {
    case dataCorrupted
    case keyNotFound(String) // TODO: Rename to "property not found"
    case objectPropertyNotFound(String, Int)
    case typeMismatch([String])
    
    case unknownObjectType(String, Int)
    case invalidObjectReference(String, String, Int)
    case invalidStructuralKeyPresent(String, StructuralType, Int)
    
    public var description: String {
        switch self {
        case .dataCorrupted: return "Corrupted or invalid data"
        case .keyNotFound(let key): return "Required key '\(key)' not found"
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


// TODO: Consolidate this with ExtendedForeignRecord
public struct ForeignObject: Codable {
    public enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case attributes
        // Structural
        case origin = "from"
        case target = "to"
        case children
    }
    public let type: String
    public let id: String?
    public let name: String?
    public let attributes: ForeignRecord?

    // Structural properties
    public let origin: String?
    public let target: String?
    public let children: [String]?
}

public struct ForeignFrameInfo: Codable {
    // FIXME: [IMPORTANT] This is not quite version change tolerant yet. It MUST be.
    // TODO: Allow objects to be embedded
    public let frameFormatVersion: String
    public let metadata: [String:ForeignValue]?
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
    
//    var infoURL: URL {
//        url.appending(component: "info.json", directoryHint: .notDirectory)
//    }
//
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
            throw FrameReaderError.keyNotFound(key.stringValue)
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

    
//    func urlForObjectContainer(_ name: String, type: String? = "json") -> URL {
//
//        url.appending(components: "objects", "\(name).json", directoryHint: .notDirectory)
//    }
    
    /// Incrementally read frame data into a mutable frame.
    ///
    /// Data is a JSON encoded array of foreign object descriptions.
    ///
    /// The process for each object in the frame data is as follows:
    /// 1. create a ``ForeignRecord`` for object's attributes
    /// 2. get a concrete object type instance basead on the type included in
    ///    the data
    /// 3. create an object snapshot in the frame using the foreign record,
    ///    object type and structural references.
    ///
    /// - Note: This function is non-transactional. The frame is assumed to
    ///         represent a transaction. When the function fails, the whole
    ///         frame should be discarded.
    ///
    public func read(_ data: Data, into frame: MutableFrame) throws {
        let decoder = JSONDecoder()
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
                throw FrameReaderError.keyNotFound(key)
            }
        }
        
        var nameToID: [String:ObjectID] = [:]
        var snapshots: [ObjectSnapshot] = []
        // 1. Instantiate objects and gather IDs
        //
        for (index, object) in objects.enumerated() {
            guard let type = metamodel.objectType(name: object.type) else {
                throw FrameReaderError.unknownObjectType(object.type, index)
            }
            
            let attributes = object.attributes ?? ForeignRecord([:])
            
            let snapshot = try memory.allocateSnapshot(type,
                                                       foreignRecord: attributes)
            if let name = object.name {
                snapshot[NameComponent.self] = NameComponent(name: name)
                nameToID[name] = snapshot.id
            }
            
            snapshots.append(snapshot)
            snapshot.makeInitialized()
            frame.insert(snapshot, owned: true)
        }
        
        // 2. Connect structure and make objects initialized (no hierarchy yet)
        for (index, (snapshot, object)) in zip(snapshots, objects).enumerated() {
            let type = snapshot.type.structuralType
            switch type {
            case .unstructured:
                guard object.origin == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("from", type, index)
                }
                guard object.target == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("to", type, index)
                }

                snapshot.structure = .unstructured

            case .node:
                guard object.origin == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("from", type, index)
                }
                guard object.target == nil else {
                    throw FrameReaderError.invalidStructuralKeyPresent("to", type, index)
                }

                snapshot.structure = .node

            case .edge:
                // First check the properties - makes tests easier
                guard let originRef = object.origin else {
                    throw FrameReaderError.objectPropertyNotFound("from", index)
                }
                guard let targetRef = object.target else {
                    throw FrameReaderError.objectPropertyNotFound("to", index)
                }

                guard let originID = nameToID[originRef] else {
                    throw FrameReaderError.invalidObjectReference(originRef, "origin", index)
                }
                guard let targetID = nameToID[targetRef] else {
                    throw FrameReaderError.invalidObjectReference(targetRef, "target", index)
                }

                snapshot.structure = .edge(originID, targetID)
            }
            // Child-parent hierarchy
        }

        // 3. Make parent-child hierarchy
        //
        // All objects are initialised now.
        
        for (index, (snapshot, object)) in zip(snapshots, objects).enumerated() {
            guard let children = object.children else {
                continue
            }
            for childRef in children {
                guard let childID = nameToID[childRef] else {
                    throw FrameReaderError.invalidObjectReference(childRef, "child", index)
                }
                frame.addChild(childID, to: snapshot.id)
            }
        }
    }
}

