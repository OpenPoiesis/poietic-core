//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 25/09/2023.
//

// TODO: [WIP] [DEPRECATED] The whole Foreign* is replaced by Raw*

public enum ForeignObjectReference: Equatable, Codable, Sendable, CustomStringConvertible {
    case id(ObjectID)
    case int(Int)
    case string(String)
    
    public var description: String {
        switch self {
        case .id(let value): value.stringValue
        case .int(let value): String(value)
        case .string(let value): value
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        else if let value = try? container.decode(Int.self) {
            self = .int(value)
        }
        else {
            let value = try container.decode(ObjectID.self)
            self = .id(value)
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .id(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        }
    }
}

public enum ForeignStructure {
    case unstructured
    case node
    case edge(ForeignObjectReference, ForeignObjectReference)
    case orderedSet(ForeignObjectReference, [ForeignObjectReference])
}


/// Protocol for foreign representation of an object
///
/// Types conforming to this type typically come from a foreign interface
/// and are meant to be loaded using the ``ForeignFrameLoader``.
///
public protocol ForeignObject {
    
    // TODO: Rename to typeName
    /// Name of the object type.
    ///
    var type: String? { get }
    
    /// Structural type of the object.
    ///
    /// Some foreign interfaces might provide this information, however the
    /// source of truth is the object type specified in the ``type``.
    ///
    var structure: ForeignStructure? { get }

    // TODO: Depreate name here, use "id"
    /// Name of the foreign object.
    ///
    /// The name is also used in the ``ForeignFrameLoader/load(_:into:)`` as
    /// an object reference.
    ///
    var name: String? { get }
    
    /// Object ID.
    ///
    /// The ID can be either real object ID or a custom string.
    ///
    var idReference: ForeignObjectReference? { get }

    /// Object snapshot ID.
    ///
    /// The ID can be either real object ID or a custom string.
    ///
    var snapshotIDReference: ForeignObjectReference? { get }

    /// Reference to a parent object.
    var parentReference: ForeignObjectReference? { get }
    
    /// Dictionary of object attributes.
    var attributes: [String:Variant] { get }
}

/// Protocol that represents a frame which originates or is meant to be used
/// by a foreign interface.
///
public protocol ForeignFrameProtocol {
    associatedtype Object: ForeignObject
    /// List of foreign objects contained in the frame.
    var objects: [Object] { get }
}


/// Error thrown when there is an issue with a foreign object, typically
/// in a foreign frame.
///
/// - SeeAlso: ``ForeignFrameError``, ``JSONFrameReader``, ``ForeignObject``
/// 
public enum ForeignObjectError: Error, Equatable, CustomStringConvertible {
    /// The external representation of foreign object is malformed.
    ///
    /// For example, a JSON representation is not a dictionary.
    ///
    case malformedObject
    /// Type of internal property is different from the expected type.
    ///
    /// First item is a property name, second is a type name as it is known to the foreign interface.
    ///
    /// The case tuple is: (_property_, _type_).
    ///
    case propertyNotFound(String)

    /// Error when there is an extra property in the object, for example an
    /// origin or a target for non-edge objects.
    ///
    case extraPropertyFound(String)

    case invalidStructureType
    
    public var description: String {
        switch self {
        case .malformedObject:
            "Malformed foreign object structure"
//        case let .typeMismatch(property, type):
//            "Type mismatch for property \(property), expected type: \(type)"
        case .propertyNotFound(let key):
            "Property '\(key)' not found"
        case .extraPropertyFound(let key):
            "Extra property '\(key)' found"
        case .invalidStructureType:
            "Invalid structure type"
        }
    }
}
