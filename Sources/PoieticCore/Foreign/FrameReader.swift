//
//  FrameReader.swift
//
//
//  Created by Stefan Urbanek on 14/08/2023.
//

import Foundation


// FIXME: [REFACTORING] Review necessity of this
/// Error thrown when reading or processing a foreign frame.
///
/// - SeeAlso: ``ForeignFrameReader``, ``ForeignObjectError``
///
public enum ForeignFrameError: Error, Equatable, CustomStringConvertible {
    case unableToReadData
    case dataCorrupted(String?)
    case typeMismatch(String, [String])
    case propertyNotFound(String, [String])
    // FIXME: [REFACTORING] REMOVE THIS
    case missingFrameFormatVersion

    case JSONError(JSONError)
    case foreignObjectError(ForeignObjectError, Int)
    case unknownObjectType(String, Int)
    case unsupportedVersion(String)
    case invalidReference(String, String, Int)
    
    
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
            self = .dataCorrupted("FIXME: VALUE NOT FOUND")
        case let .keyNotFound(key, context):
            let path = context.codingPath.map { $0.stringValue }
            let key = key.stringValue
            self = .propertyNotFound(key, path)
        case let .dataCorrupted(context):
            self = .dataCorrupted("FIXME: DATA CORRUPTED")
        @unknown default:
            self = .dataCorrupted("FIXME: UNKNOWN FUTURE")
        }
    }
    
    
    public var description: String {
        switch self {
        case .unableToReadData:
            "Unable to read frame data"
        case .dataCorrupted(let detail):
            "Data corrupted: \(detail)"
        case .typeMismatch(let expected, let path):
            if path.isEmpty {
                "Type mismatch. Expected the top level to be \(expected)."
            }
            else {
                "Type mismatch. Expected \(expected) at \(path)."
            }
        case .propertyNotFound(let property, let path):
            if path.isEmpty {
                "Property '\(property)' not found."
            }
            else {
                "Property '\(property)' not found at \(path)."
            }
        case .JSONError(let error):
            "JSON error: \(error)"
        case .foreignObjectError(let error, let index):
            "Error in object at \(index): \(error)"
        case .unknownObjectType(let type, let index):
            "Unknown object type '\(type)' for object at index \(index)"
        case .missingFrameFormatVersion:
            "Missing frame format version"
        case .unsupportedVersion(let version):
            "Unsupported version: \(version)"
        case let .invalidReference(ref, kind, index):
            "Invalid \(kind) object reference '\(ref)' in object at index \(index)"
        }
    }
}

