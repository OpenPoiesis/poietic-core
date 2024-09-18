//
//  JSONFrameReader.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation

/// Helper structure to convert objects to and from JSON using coding.
///
/// This structure is just a helper to have better control over JSON using
/// the built-in ``Codable`` protocol.
///
private struct _JSONForeignObject: Codable, ForeignObject {
    var id: String?
    var snapshotID: String?
    var name: String?
    var type: String?
    var origin: String?
    var target: String?
    var parent: String?
    var children: [String]
    var structuralType: StructuralType?
    var attributes: [String:Variant]
    
    enum CodingKeys: String, CodingKey {
        case id
        case snapshotID = "snapshot_id"
        case name
        case type
        case structuralType = "structure"
        case origin = "from"
        case target = "to"
        case parent
        case children
        case attributes
    }
   
    init(_ object: ObjectSnapshot) {
        let originString: String?
        let targetString: String?
        
        switch object.structure {
        case let .edge(origin, target):
            originString = String(origin)
            targetString = String(target)
        case .unstructured, .node:
            originString = nil
            targetString = nil
        }
        
        self.id = String(object.id)
        self.snapshotID = String(object.snapshotID)
        self.type = object.type.name
        self.origin = originString
        self.target =  targetString
        if let parent = object.parent {
            self.parent = String(parent)
        }
        else {
            self.parent = nil
        }
        self.children = object.children.map { String($0) }
        self.structuralType = object.structure.type
        
        var attributes: [String:Variant] = [:]
        for (key, value) in object.attributes {
            attributes[key] = value
        }
        self.attributes = attributes
    }
    
    init(from decoder: Decoder) throws {
        // if decoder.userInfo[JSONFrameReader.Version] as? String == "" {
        // }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        snapshotID = try container.decodeIfPresent(String.self, forKey: .snapshotID)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        structuralType = try container.decodeIfPresent(StructuralType.self, forKey: .structuralType)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        target = try container.decodeIfPresent(String.self, forKey: .target)
        parent = try container.decodeIfPresent(String.self, forKey: .parent)
        children = try container.decodeIfPresent([String].self, forKey: .children) ?? []
        attributes = try container.decodeIfPresent([String:Variant].self, forKey: .attributes) ?? [:]
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(snapshotID, forKey: .snapshotID)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encodeIfPresent(parent, forKey: .parent)
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
        try container.encode(attributes, forKey: .attributes)
    }
}

/// Helper structure to convert frames to and from JSON using coding.
///
/// This structure is just a helper to have better control over JSON using
/// the built-in ``Codable`` protocol.
///
private struct _JSONForeignFrameContainer: Codable {
    let metamodel: String?
    let collectionNames: [String]
    let objects: [_JSONForeignObject]
    
    enum CodingKeys: String, CodingKey {
        // FIXME: [REFACTORING] Change to "format_version"
        case version = "frame_format_version"
        case metamodel
        case collectionNames = "collections"
        case objects
    }
    
    init(from decoder: Decoder) throws {
        // if decoder.userInfo[JSONFrameReader.Version] as? String == "" {
        // }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // TODO: Act accordingly to the version
        let _ = try container.decode(String.self, forKey: .version)
        
        metamodel = try container.decodeIfPresent(String.self, forKey: .metamodel)
        collectionNames = try container.decodeIfPresent([String].self, forKey: .collectionNames) ?? []
        objects = try container.decodeIfPresent([_JSONForeignObject].self, forKey: .objects) ?? []
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(metamodel, forKey: .metamodel)
        if !collectionNames.isEmpty {
            try container.encodeIfPresent(collectionNames, forKey: .collectionNames)
        }
        if !objects.isEmpty {
            try container.encodeIfPresent(objects, forKey: .objects)
        }
    }
}

private struct _JSONForeignObjectCollection: Codable {
    let objects: [_JSONForeignObject]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.objects = try container.decode([_JSONForeignObject].self)
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(objects)
    }
}

private struct _JSONForeignFrame: ForeignFrame {
    let container: _JSONForeignFrameContainer
    let collections: [String:_JSONForeignObjectCollection]
    
    var objects: [ForeignObject] {
        container.objects + collections.values.flatMap({$0.objects})
    }
}

/// Object for reading foreign frames represented as JSON.
///
/// ## Foreign Objects
///
/// The JSON representation of foreign object is a dictionary with the following
/// keys:
///
/// - `id` (optional): Object ID, if not provided, one will be generated during
///   loading.
/// - `snapshot_id` (optional): snapshot ID, if not provided, one will be
///   generated during loading
/// - `name` (optional): used as both, object name and an object reference.
///   See note below about references. If provided, it will be used as
///   an attribute `name` of the object.
/// - `type` (required): name of the object type. During the loading process
///   the type must be known to the loader.
/// - `from` (contextual): if the object is an edge, the property references its origin
/// - `to` (contextual): if the object is an edge, the property references its target
/// - `parent` (optional): reference to object's parent
/// - `children` (optional): list of object's children – convenience mechanism
///    for parent-child relationships, only recommended for hand-written frames
/// - `attributes`: a dictionary where keys are attribute names and values are
///    attribute values.
///
/// ## References
///
/// Typically the unique identifier of an object within a frame is its ID.
/// For convenience of hand-writing small foreign frames, objects can be
/// referenced by their names as well. One can refer to an object by its
/// name in an edge origin or a target, for example.
///
/// When multiple objects have the same name, then which object will be
/// referred to is undefined.
///
/// - Note: Hand-writing foreign frames is discouraged, as they might become
///   complex very quickly. It is not the purpose of this toolkit to
///   process and maintain raw human-written textual representation of models.
///
public final class JSONFrameReader {
    public static let VersionKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "JSONForeignFrameVersion")!

    // NOTE: For now, the class exists only for code organisation purposes/name-spacing
   
    /// Create a frame reader.
    ///
    public init() {
        // Nothing here for now
    }

    /// Read a frame bundle at a file system path.
    ///
    /// - SeeAlso: ``JSONFrameReader/read(bundleAtURL:)``
    ///
    public func read(path: String) throws (ForeignFrameError) -> ForeignFrame {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return try read(bundleAtURL: url)
    }
    
    /// Read a frame bundle at a given URL.
    ///
    /// The bundle is a directory with the following content:
    ///
    /// - `info.json` – information about the frame. A dictionary containing the
    ///   following keys:
    ///     - `frame_format_version`: Version of the frame format (required)
    ///     - `objects`: An array of objects (see the class information about
    ///        details)
    ///     - `collections`: List of collection names, where each collection is
    ///       a separate file.
    /// - `objects/` directory with JSON files where each file represents an
    ///   object collection. The names in this directory should correspond
    ///   to the names in the `collections` array.
    ///
    /// Example:
    ///
    /// ```
    /// MyModel.poieticframe/
    ///     info.json
    ///     objects/
    ///         design.json
    ///         core.json
    ///         charts.json
    /// ```
    ///
    public func read(bundleAtURL url: URL) throws (ForeignFrameError) -> ForeignFrame {
        let container: _JSONForeignFrameContainer
        let decoder = JSONDecoder()
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
        
        let infoURL = url.appending(component: "info.json")
        do {
            let data = try Data(contentsOf: infoURL)
            container = try decoder.decode(_JSONForeignFrameContainer.self, from: data)
        }
        catch {
            throw .dataCorrupted(nil)
        }
        var collections: [String:_JSONForeignObjectCollection] = [:]
        for name in container.collectionNames {
            let collectionURL = url.appending(components: "objects", "\(name).json", directoryHint: .notDirectory)
            do {
                let data = try Data(contentsOf: collectionURL)
                let collection = try decoder.decode(_JSONForeignObjectCollection.self, from: data)
                collections[name] = collection
            }
            catch let error as DecodingError {
                throw ForeignFrameError(error)
            }
            catch {
                // FIXME: [REFACTORING]
                throw .dataCorrupted("FIXME UNKNOWN ERROR")
            }
        }

        return _JSONForeignFrame(container: container, collections: collections)
    }
    
    /// Read a frame file at a given URL.
    ///
    /// The frame file is a JSON file with the following content:
    ///
    /// - `frame_format_version`: Version of the frame format (required)
    /// - `objects`: An array of objects (see the class information about
    ///    details)
    ///
    public func read(fileAtURL url: URL) throws (ForeignFrameError) -> ForeignFrame {
        do {
            let data = try Data(contentsOf: url)
            return try self.read(data: data)
        }
        catch let error as DecodingError {
            throw ForeignFrameError(error)
        }
        catch {
            // FIXME: [REFACTORING]
            throw .dataCorrupted("FIXME UNKNOWN ERROR")
        }
    }

    public func read(data: Data) throws (ForeignFrameError) -> ForeignFrame {
        let decoder = JSONDecoder()
        
        decoder.userInfo[Variant.CoalescedCodingTypeKey] = true

        let container: _JSONForeignFrameContainer
        do {
            container = try decoder.decode(_JSONForeignFrameContainer.self, from: data)
        }
        catch let error as DecodingError {
            throw ForeignFrameError(error)
        }
        catch {
            // FIXME: [REFACTORING]
            throw .dataCorrupted("FIXME UNKNOWN ERROR")
        }
        guard container.collectionNames.isEmpty else {
            fatalError("Foreign frame from data (inline frame) must not refer to other collections, only bundle foreign frame can.")
        }

        return _JSONForeignFrame(container: container, collections: [:])
    }
}

// FIXME: [REFACTORING] Move out of this file
/// Utility class.
///
/// - Note: This is just a prototype of a functionality.
///
public final class JSONFrameWriter {
    static public func objectToJSON(_ object: ObjectSnapshot) throws -> Data {
        let foreign = _JSONForeignObject(object)
        let encoder = JSONEncoder()
        let data = try encoder.encode(foreign)
        return data
    }
}
