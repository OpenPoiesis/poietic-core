//
//  FrameReader.swift
//
//
//  Created by Stefan Urbanek on 14/08/2023.
//

import Foundation


// FIXME: Review necessity of this
/// Error thrown when reading or processing a foreign frame.
///
/// - SeeAlso: ``ForeignFrameLoader``, ``ForeignObjectError``
///
public enum ForeignFrameError: Error, Equatable, CustomStringConvertible {
    /// Data is corrupted and can not be even read using given reader.
    ///
    /// The user is advised to use reader format specific tools to validate the foreign data
    /// format.
    ///
    /// For example, for JSON frame reader, the file must be valid JSON. Use tools such as `jq` to
    /// validate the foreign frame data.
    ///
    case dataCorrupted(String)
    
    /// The root object of the foreign frame is not as expected.
    ///
    /// Typically the root object is of a different type. For example, for a JSON foreign frame,
    /// the root is expected to be a dictionary. For EDN foreign frame, the root is expected to be
    /// a list.
    /// 
    case invalidRoot
    case unsupportedVersion(String)

    case unableToReadData
    case typeMismatch(String, [String])
    case propertyNotFound(String, [String])
    case valueNotFound(String, [String])
    case invalidValue(String, [String])
    
    case JSONError(JSONError)
    case foreignObjectError(ForeignObjectError, Int)
    case unknownObjectType(String, Int)

    /// Invalid object reference.
    ///
    /// Items are (_reference_, _kind_, _index_).
    ///
    case invalidReference(String, String, Int)
    
    case unknownDecodingError(String)
    
    // FIXME: This is JSON specific
    init(_ error: DecodingError) {
        switch error {
            
        case let .typeMismatch(type, context):
            let path = context.codingPath.map { $0.stringValue }
            if type.self is Dictionary<String, Any>.Type {
                self = .typeMismatch("dictionary", path)
            }
            else if type.self is Array<Any>.Type {
                self = .typeMismatch("array", path)
            }
            else {
                self = .typeMismatch("\(type)", path)
            }

        case let .valueNotFound(key, context):
            let path = context.codingPath.map { $0.stringValue }
            self = .valueNotFound(String(describing: key), path)
            
        case let .keyNotFound(key, context):
            let path = context.codingPath.map { $0.stringValue }
            let key = key.stringValue
            self = .propertyNotFound(key, path)

        case let .dataCorrupted(context):
            self = .dataCorrupted(context.debugDescription)

        @unknown default:
            self = .unknownDecodingError(String(describing: error))
        }
    }
    
    public var description: String {
        switch self {
        case .unableToReadData:
            return "Unable to read frame data"
        case .dataCorrupted(let detail):
            return "Data corrupted: \(detail)"
        case .invalidRoot:
            return "Invalid root object"
        case .typeMismatch(let expected, let path):
            let message = "Type mismatch. Expected the top level to be \(expected)"
            if path.isEmpty {
                return message
            }
            else {
                return message + " at \(path)."
            }
        case .propertyNotFound(let property, let path):
            let message = "Property '\(property)' not found."
            if path.isEmpty {
                return message
            }
            else {
                return message + " at \(path)."
            }
        case .invalidValue(let property, let path):
            let message = "Invalid value for '\(property)'"
            if path.isEmpty {
                return message
            }
            else {
                return message + " at \(path)."
            }
        case .JSONError(let error):
            return "JSON error: \(error)"
        case .foreignObjectError(let error, let index):
            return "Error in object at \(index): \(error)"
        case .unknownObjectType(let type, let index):
            return "Unknown object type '\(type)' for object at index \(index)"
        case .unsupportedVersion(let version):
            return "Unsupported version: \(version)"
        case let .invalidReference(ref, kind, index):
            return "Invalid \(kind) object reference '\(ref)' in object at index \(index)"
        case .unknownDecodingError(let error):
            return "Unknown decoding error: \(error)"
        case .valueNotFound(let value, let path):
            if path.isEmpty {
                return "Value not found for \(value)."
            }
            else {
                return "Value not found for \(value) at \(path)."
            }
        }
    }
}

