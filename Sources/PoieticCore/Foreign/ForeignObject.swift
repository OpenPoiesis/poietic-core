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
