//
//  StoreError.swift
//  
//
//  Created by Stefan Urbanek on 08/05/2024.
//

import Foundation

/// An error thrown when saving and restoring a design to/from a persistent
/// store.
///
/// - SeeAlso: ``MakeshiftDesignStore/load(metamodel:)``,
///   ``MakeshiftDesignStore/save(design:)``
///
public enum PersistentStoreError: Error, Equatable, CustomStringConvertible {
    case unhandledError(String)
    
    // Main errors
    case storeMissing
    case cannotOpenStore(URL)
    case unableToWrite(URL)
    case dataCorrupted
    case unsupportedFormatVersion(String)

    // Decoding errors
    case missingProperty(String, [String])
    case missingValue(String, [String])
    case typeMismatch([String])
    
    // The following errors can be put under a single error "dataStructureIntegrityError".
    // Users should not be bothered with the details of the error, only tool developers.

    // Integrity errors
    case duplicateID(ObjectID, String)
    case unknownObjectType(String)
    case invalidStructuralType(String)
    case structuralTypeMismatch(StructuralType, StructuralType)
    case duplicateSnapshot(ObjectID)
    case extraneousStructuralProperty(StructuralType, String)
    case missingStructuralProperty(StructuralType, String)
    case duplicateFrame(ObjectID)
    case invalidSnapshotReference(ObjectID, ObjectID)
    case frameValidationFailed(ObjectID)
    case currentFrameIDNotSet
    case invalidFrameReference(String, ObjectID)
    
    case invalidRootData
    
    public var description: String {
        switch self {
        case .dataCorrupted:
            "Store data is corrupted"
        case .invalidRootData:
            // HINT: Use doctor
            "Root store data is invalid"
        
        case .unhandledError(let error):
            "Unhandled internal error: \(error)"
        // Main errors
        case .storeMissing:
            "Design store is missing (no data or no URL)."
        case let .cannotOpenStore(url):
            "Can not open design store: \(url.absoluteString)"
        case let .unableToWrite(url):
            "Can not write store to: \(url.absoluteString)"
        case let .unsupportedFormatVersion(version):
            "Unsupported store format version: \(version)"

        // Decoding errors
        case let .missingProperty(property, path):
            "Missing property '\(property)' at \(path)"
        case let .missingValue(property, path):
            "Missing value for property '\(property)' at \(path)"
        case let .typeMismatch(path):
            "Type mismatch at key path \(path)"

        // Integrity errors
        case let .duplicateID(id, what):
            "Duplicate ID \(id) in \(what)"
        case let .unknownObjectType(type):
            "Unknown object type '\(type)'"
        case let .invalidStructuralType(type):
            "Invalid structural type '\(type)'"
        case let .structuralTypeMismatch(expected, provided):
            "Structural type mismatch, expected: \(expected), provided: \(provided)"
        case let .duplicateSnapshot(id):
            "Duplicate snapshot \(id)"
        case let .duplicateFrame(id):
            "Duplicate frame \(id)"
        case let .invalidSnapshotReference(owner, ref):
            "Invalid snapshot reference \(ref) in \(owner)"
        case let .missingStructuralProperty(type, property):
            "Missing structural property \(property) for \(type)"
        case let .extraneousStructuralProperty(type, property):
            "Extraneous structural property \(property) for \(type)"
        case     .currentFrameIDNotSet:
            "Missing current frame ID"
        case let .frameValidationFailed(id):
            "Constraint validation of frame \(id) failed"
        case let .invalidFrameReference(context, id):
            "Invalid frame reference: \(id) in: \(context)"
        }
    }

}
