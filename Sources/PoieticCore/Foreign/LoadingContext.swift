//
//  IdentityReservation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 07/05/2025.
//


/// Error thrown when requesting reservation of an ID.
///
public enum IdentityError: Error, Equatable, CustomStringConvertible {
    // TODO: Move to identity manager
    /// Requested ID is not known.
    case unknownID
    /// Requested ID is already registered or used.
    case duplicateID
    /// Requested ID is known (registered or used), however its type is of different entity type.
    case typeMismatch
    /// Entity type of requested ID is unknown or invalid. This can happen during loading.
    case unknownType

    public var description: String {
        switch self {
        case .unknownID: "Unknown ID"
        case .duplicateID: "Duplicate ID"
        case .typeMismatch: "Entity ID type mismatch"
        case .unknownType: "Unknown entity type"
        }
    }
}

public struct IdentityCollectionError: Error, Equatable, CustomStringConvertible {
    let index: Int
    let error: IdentityError
    
    public var description: String {
        "Identity reservation error at index \(index), reason: \(error)"
    }
}

