//
//  DesignLoaderError.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 18/10/2025.
//

/// Error thrown by the design loader.
///
/// - SeeAlso: ``DesignLoader/load(_:into:)-6m9va``, ``DesignLoader/load(_:into:)-1o6qf``
///
public enum DesignLoaderError: Error, Equatable, Sendable {
    // TODO: Add CustomStringConvertible
    case design(DesignError)
    case collection(CollectionType, CollectionError)
    case item(CollectionType, Int, ItemError)
    
    /// Error of unspecified type that should be caught and wrapped as .item error by the caller.
    struct IndexedItemError: Error, Equatable {
        let index: Int
        let error: ItemError
        init(_ index: Int, _ error: ItemError) {
            self.index = index
            self.error = error
        }
    }
    
    public enum CollectionType: Sendable, Equatable {
        case objectSnapshots
        case frames
        case userReferences
        case userLists
        case systemReferences
        case systemLists
    }

    public enum CollectionError: Error, Equatable, Sendable {
    }
    
    public enum ItemError: Error, Equatable, Sendable {
        case unknownEntityType(String)

        // Identity
        /// Unable to reserve requested foreign ID as given type.
        case reservationConflict(IdentityType, ForeignEntityID)
        case duplicateEntityID(IdentityType, EntityID.RawValue)

        case unknownID(ForeignEntityID)
        case duplicateForeignID(ForeignEntityID)
        case IDTypeMismatch
        
        // Snapshot-specific
        case missingObjectType
        case unknownObjectType(String)
        case invalidStructuralType
        case structuralTypeMismatch(StructuralType)
        
        // Frame-specific
        case unknownSnapshotID(ForeignEntityID)
        case duplicateObject(ForeignEntityID)
        case brokenStructuralIntegrity(StructuralIntegrityError)

        // Hierarchy
        case unknownParent
        case childrenMismatch

        // Other
        case duplicateName(String)

    }
    
    public enum DesignError: Error, Equatable, Sendable {
        case missingCurrentFrame
        case namedReferenceTypeMismatch(String)
        case unknownFrameID(ForeignEntityID)
    }
}
