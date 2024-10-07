//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 25/09/2023.
//


/// Protocol for foreign representation of an object
///
/// Types conforming to this type typically come from a foreign interface
/// and are meant to be loaded using the ``ForeignFrameLoader``.
///
public protocol ForeignObject {
    
    /// Name of the object type.
    ///
    var type: String? { get }
    
    /// Structural type of the object.
    ///
    /// Some foreign interfaces might provide this information, however the
    /// source of truth is the object type specified in the ``type``.
    ///
    var structuralType: StructuralType? { get }

    // FIXME: Depreate name here, use "id"
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
    var id: String? { get }

    /// Object snapshot ID.
    ///
    /// The ID can be either real object ID or a custom string.
    ///
    var snapshotID: String? { get }

    /// Reference to an object that is an origin of an edge.
    var origin: String? { get }

    /// Reference to an object that is a target of an edge.
    var target: String? { get }
    
    /// Reference to a parent object.
    var parent: String? { get }
    
    /// List of references for object's children.
    var children: [String] { get }
    
    /// Dictionary of object attributes.
    var attributes: [String:Variant] { get }
}

extension ForeignObject {
    public func validateStructure(_ structuralType: StructuralType) throws (ForeignObjectError) {
        switch structuralType {
        case .unstructured:
            guard origin == nil else {
                throw .extraPropertyFound("from")
            }
            guard target == nil else {
                throw .extraPropertyFound("to")
            }
        case .node:
            guard origin == nil else {
                throw .extraPropertyFound("from")
            }
            guard target == nil else {
                throw .extraPropertyFound("to")
            }
        case .edge:
            guard origin != nil else {
                throw .propertyNotFound("from")
            }
            guard target != nil else {
                throw .propertyNotFound("to")
            }
        }

    }
}

/// Protocol that represents a frame which originates or is meant to be used
/// by a foreign interface.
///
public protocol ForeignFrame {
    /// List of foreign objects contained in the frame.
    var objects: [ForeignObject] { get }
}


/// Error thrown when there is an issue with a foreign object, typically
/// in a foreign frame.
///
/// - SeeAlso: ``ForeignFrameError``, ``JSONFrameReader``, ``ForeignObject``
/// 
public enum ForeignObjectError: Error, Equatable {
    /// The external representation of foreign object is malformed.
    ///
    /// For example, a JSON representation is not a dictionary.
    ///
    case malformedForeignObject
    case foreignValueError(String, ForeignValueError)
    case valueError(String, ValueError)
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
    
    case malformedAttributes

    init(_ error: ForeignRecordError) {
        switch error {
        case .unknownKey(let key):
            self = .propertyNotFound(key)
        case .valueError(let key, let error):
            self = .valueError(key, error)
            
        }
    }
    
    public var description: String {
        switch self {
        case .malformedForeignObject:
            "Malformed foreign object structure"
        case .foreignValueError(let error, _):
            "Value error: \(error)"
        case .valueError(let key, let error):
            "Value error for key '\(key)': \(error)"
        case .missingObjectType:
            "Missing object type"
        case .typeMismatch(let expected, let provided):
            "Type mismatch. Expected: \(expected), got: \(provided)"
        case .propertyNotFound(let key):
            "Property '\(key)' not found"
        case .extraPropertyFound(let key):
            "Extra property '\(key)' found"
        case .malformedAttributes:
            "Malformed attributes structure"

        }
    }
}
