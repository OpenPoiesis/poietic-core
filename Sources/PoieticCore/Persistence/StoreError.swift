//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/05/2024.
//

import Foundation

public enum PersistentStoreError: Error, Equatable, CustomStringConvertible {
    // Tested:
    case storeMissing
    case cannotOpenStore(URL)
    case dataCorrupted
    case missingProperty(String, [String])
    case typeMismatch([String])
    case unknownObjectType(String)
    case invalidStructuralType(String)
    case structuralTypeMismatch(StructuralType, StructuralType)
    case duplicateSnapshot(ObjectID)
    
    // NOT TESTED:
    case duplicateFrame(ObjectID)
    case invalidSnapshotReference(ObjectID, ObjectID)
    case missingStructuralProperty(StructuralType, String)
    case extraneousStructuralProperty(StructuralType, String)
    case currentFrameIDNotSet
    case unsupportedFormatVersion(String)
    case invalidFrameReference(String, ObjectID)
    
    case frameConstraintError(ObjectID)

    public var description: String {
        switch self {
        case .storeMissing:
            "Design store is missing (no data or no URL)."
        case let .cannotOpenStore(url):
            "Can not open design store: \(url)"
        case .dataCorrupted:
            "Store data is corrupted"
        case let .missingProperty(property, path):
            "Missing property '\(property)' at \(path)"
        case let .typeMismatch(path):
            "Type mismatch at key path \(path)"
        case let .unknownObjectType(type):
            "Unknown object type '\(type)'"
        case let .invalidStructuralType(type):
            "Invalid structural type '\(type)'"
        case let .structuralTypeMismatch(expected, provided):
            "Structural type mismatch, expected: \(expected), provided: \(provided)"
        case let .duplicateSnapshot(id):
            "Duplicate snapshot \(id)"
        
        // NOT TESTED:
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
        case let .unsupportedFormatVersion(version):
            "Unsupported format version: \(version)"
        case let .invalidFrameReference(context, id):
            "Invalid frame reference \(id) in \(context)"
        case let .frameConstraintError(id):
            "Constraint error in frame \(id)"
        }
    }

}
