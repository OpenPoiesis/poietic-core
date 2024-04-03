//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 25/09/2023.
//

/// Error thrown when there is an issue with a foreign object, typically
/// in a foreign frame.
///
/// - SeeAlso: ``ForeignFrameError``, ``ForeignFrameReader``, ``ForeignObject``
public enum ForeignObjectError: Error, Equatable {
    /// Foreign object does not have an object type specified while it is
    /// required.
    ///
    /// Typically object type is required for reading foreign frames.
    /// However, foreign objects do not have to contain object type in their
    /// info record if a reader assumes a batch of foreign objects to be of
    /// the same type.
    case missingObjectType
    
    /// Error for type mismatch of known properties, such as ID or object type.
    ///
    case typeMismatch(ValueType, String)
    
    
    /// Required property not found in object.
    ///
    case propertyNotFound(String)
    
    /// Error when there is an extra property in the object, for example an
    /// origin or a target for non-edge objects.
    ///
    case extraPropertyFound(String)
    
    public var description: String {
        switch self {
            
        case .missingObjectType:
            "Missing object type"
        case .typeMismatch(let expected, let provided):
            "Type mismatch. Expected: \(expected), got: \(provided)"
        case .propertyNotFound(let key):
            "Property '\(key)' not found"
        case .extraPropertyFound(let key):
            "Extra property '\(key)' found"
        }
    }
}


/// A structure that contains an object representation from a foreign interface.
///
/// The `ForeignObject` structure is used to import and export objects from
/// the object design.
///
public struct ForeignObject {
    /// Information about the object.
    ///
    /// The info record may include one or more of the following, depending
    /// on the foreign object reading policy.
    ///
    /// - `type` - object type name, see ``type`` for more information.
    /// - `id` - object id in proper ID format
    /// - `snapshot_id` - snapshot ID in proper object ID format
    /// - `name` - object reference. See ``name`` for more information.
    /// - `from`, `to` – edge endpoints, if the object type is an edge
    ///
    /// - Note: If the object type is not an edge, then the foreign object info
    ///   record must _not_ contain the `from` and `to` attributes.
    ///
    public let info: ForeignRecord
    
    /// Attributes and their values.
    ///
    /// If the foreign record contains attribute `name` it will be used
    /// instead of the ``name`` attribute of the foreign object.
    ///
    /// - Note: The attribute values must not contain any object references.
    ///
    /// - SeeAlso: ``ObjectSnapshot/attributes``, ``name``
    ///
    public let attributes: ForeignRecord
   
    /// Convenience attribute for object name.
    ///
    /// The name might be also used by foreign interfaces as an object
    /// reference. However, when there are objects with multiple names,
    /// the behaviour is unspecified, typically might result in an error.
    ///
    /// Using _name_ as an object reference is just for human convenience in
    /// small hand-written designs and should not be used when
    /// importing/exporting objects for non-human use.
    ///
    /// If the foreign record contains attribute `name` it will be used
    /// instead of this _name_ attribute of the foreign object.
    ///
    /// - SeeAlso: ``attributes``, ``id``
    ///
    public var name: String? {
        get throws {
            do {
                return try info.stringValueIfPresent(for: "name")
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.string, "name")
            }
        }
    }
    
    /// Type name of the object.
    ///
    /// The type name refers to an ``ObjectType`` in the
    /// metamodel ``Metamodel/objectTypes`` .
    ///
    public var type: String? {
        get throws {
            do {
                return try info.stringValueIfPresent(for: "type")
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.string, "type")
            }
        }
    }

    /// Reference to an object.
    ///
    /// Convenience for fetching string representation of object ID stored in the info record.
    ///
    /// When importing, the foreign references can be IDs or object names,
    /// depending on the foreign interface. The IDs must be valid within the
    /// batch of object being imported.
    ///
    /// Using _name_ as an object reference is just for human convenience in
    /// small hand-written designs and should not be used when
    /// importing/exporting objects for non-human use.
    ///
    /// When exporting the IDs are the represented object IDs.
    ///
    /// - SeeAlso: ``name``, ``ObjectSnapshot/id``
    ///
    public var id: String? {
        // TODO: [REFACTORING] Validate correct ID instead of String
        get throws {
            do {
                return try info.stringValueIfPresent(for: "id")
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.string, "id")
            }
        }
    }

    /// Convenience for fetching correctly typed snapshot ID stored in the info record.
    ///
    public var snapshotID: String? {
        // TODO: [REFACTORING] Validate correct ID instead of String
        get throws {
            do {
                return try info.stringValueIfPresent(for: "snapshot_id")
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.string, "snapshot_id")
            }
        }
    }

    /// Origin of an edge if the structural type of the object is an edge.
    ///
    /// The attribute must be present together with the ``target`` attribute.
    /// The attribute must not be present for any non-edge structure.
    ///
    /// - SeeAlso: ``target``, ``id``, ``name``
    ///
    public var origin: String? {
        get throws {
            do {
                return try info.stringValueIfPresent(for: "from")
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.string, "from")
            }
        }
    }
    /// Target of an edge if the structural type of the object is an edge.
    ///
    /// The attribute must be present together with the ``origin`` attribute.
    /// The attribute must not be present for any non-edge structure.
    ///
    /// - SeeAlso: ``origin``, ``id``, ``name``
    ///
    public var target: String? {
        get throws {
            do {
                return try info.stringValueIfPresent(for: "to")
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.string, "to")
            }
        }
    }
    /// List of references to the object's children to form the object
    /// hierarchy.
    ///
    /// - SeeAlso: ``id``, ``ObjectSnapshot/children``
    ///
    public var children: [String]? {
        get throws {
            do {
                guard let children = info["children"] else {
                    return nil
                }
                
                return try children.stringArray()
            }
            catch JSONError.typeMismatch(.string, _) {
                throw ForeignObjectError.typeMismatch(.strings, "children")
            }
        }
    }

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

// TODO: Where this should belong? This is here only for the server, as it requires Encodable, for now.

extension ForeignObject: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: ObjectSnapshot.ForeignObjectCodingKeys.self)
        try container.encode(info.stringValue(for: "id"), forKey: .id)
        try container.encode(info.stringValue(for: "snapshot_id"), forKey: .snapshotID)
        try container.encode(info.stringValue(for: "type"), forKey: .type)
        try container.encode(info.stringValue(for: "structure"), forKey: .structure)
        if let origin = try info.stringValueIfPresent(for: "origin") {
            try container.encode(origin, forKey: .origin)
        }
        if let target = try info.stringValueIfPresent(for: "target") {
            try container.encode(target, forKey: .target)
        }
        if let parent = try info.stringValueIfPresent(for: "parent") {
            try container.encode(parent, forKey: .parent)
        }
        try container.encode(attributes, forKey: .attributes)
    }
}
