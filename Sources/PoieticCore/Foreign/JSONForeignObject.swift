//
//  JSONForeignObject.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 22/10/2024.
//

/// Helper structure to convert objects to and from JSON using coding.
///
/// This structure is just a helper to have better control over JSON using
/// the built-in ``Codable`` protocol.
///
public struct JSONForeignObject: Codable, ForeignObject {
    public var id: String?
    public var snapshotID: String?
    public var name: String?
    public var type: String?
    public var origin: String?
    public var target: String?
    public var parent: String?
    public var children: [String]
    public var structuralType: StructuralType?
    public var attributes: [String:Variant]
    
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
   
    public init(_ object: ObjectSnapshot) {
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
    
    public init(from decoder: Decoder) throws {
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
    public func encode(to encoder: any Encoder) throws {
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
package struct _JSONForeignFrameContainer: Codable {
    package let metamodel: String?
    package let collectionNames: [String]
    package let objects: [JSONForeignObject]
    
    enum CodingKeys: String, CodingKey {
        // FIXME: [REFACTORING] Change to "format_version"
        case version = "frame_format_version"
        case metamodel
        case collectionNames = "collections"
        case objects
    }
    
    package init(from decoder: Decoder) throws {
        // if decoder.userInfo[JSONFrameReader.Version] as? String == "" {
        // }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // TODO: Act accordingly to the version
        let _ = try container.decode(String.self, forKey: .version)
        
        metamodel = try container.decodeIfPresent(String.self, forKey: .metamodel)
        collectionNames = try container.decodeIfPresent([String].self, forKey: .collectionNames) ?? []
        objects = try container.decodeIfPresent([JSONForeignObject].self, forKey: .objects) ?? []
    }
    package func encode(to encoder: any Encoder) throws {
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

package struct _JSONForeignObjectCollection: Codable {
    package let objects: [JSONForeignObject]

    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.objects = try container.decode([JSONForeignObject].self)
    }
    package func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(objects)
    }
}

package struct _JSONForeignFrame: ForeignFrame {
    package let container: _JSONForeignFrameContainer
    package let collections: [String:_JSONForeignObjectCollection]
    
    package var objects: [ForeignObject] {
        container.objects + collections.values.flatMap({$0.objects})
    }
}
