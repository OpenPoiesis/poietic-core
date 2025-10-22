//
//  DesignLoaderError.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 18/10/2025.
//

/// Error thrown by the design loader.
///
/// - SeeAlso: ``DesignLoader/load(_:)``, ``DesignLoader/load(_:into:)``
///
public enum DesignLoaderError: Error, Equatable, Sendable, CustomStringConvertible {
    // TODO: Add CustomStringConvertible
    case design(DesignError)
    /// Error with a collection as a whole
    case collection(CollectionType, CollectionError)
    /// Error with a particular item in a collection of raw (foreign) objetcs.
    ///
    /// Elements of the case: collection type, index of the offending item, concrete item error.
    case item(CollectionType, Int, ItemError)
    
    public var description: String {
        switch self {
        case let .design(error): error.description
        case let .collection(type, error): "Error in \(type): " + error.description
        case let .item(type, index, error): "Error in \(type) at index \(index): " + error.description
        }
    }
    
    public var hint: String? {
        switch self {
        case let .design(error): error.hint
        case let .collection(_, error): error.hint
        case let .item(_, _, error): error.hint
        }
    }

    /// Error of unspecified type that should be caught and wrapped as .item error by the caller.
    struct IndexedItemError: Error, Equatable {
        let index: Int
        let error: ItemError
        init(_ index: Int, _ error: ItemError) {
            self.index = index
            self.error = error
        }
    }
    
    public enum CollectionType: Sendable, Equatable, CustomStringConvertible {
        case objectSnapshots
        case frames
        case userReferences
        case userLists
        case systemReferences
        case systemLists
        
        public var description: String {
             switch self {
             case .objectSnapshots: "object snapshots"
             case .frames: "frames"
             case .userLists: "user lists"
             case .userReferences: "user references"
             case .systemLists: "system lists"
             case .systemReferences: "system references"
             }
        }
    }

    // TODO: Do we still need this?
    public enum CollectionError: Error, Equatable, Sendable, CustomStringConvertible {
        public var description: String {
            "unknown error"
        }
        public var hint:String? { nil }
    }
    
    public enum ItemError: Error, Equatable, Sendable, CustomStringConvertible {
        case unknownEntityType(String)
        case unknownID(ForeignEntityID)
        
        // Identity
        /// Unable to reserve requested foreign ID as given type.
        case reservationConflict(IdentityType, ForeignEntityID)
        case duplicateForeignID(ForeignEntityID)
        
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
        
        public var description: String {
            switch self {
            case let .unknownEntityType(type): "Unknown design entity type '\(type)'"
            case let .unknownID(id): "Unknown ID '\(id)'"

            // Identity reservation
            case let .reservationConflict(type, id): "Conflict during ID reservation for '\(id)' of type \(type)"
            case let .duplicateForeignID(id): "Duplicate ID '\(id)'"

            // Snapshot-specific
            case .missingObjectType: "Missing object type name"
            case let .unknownObjectType(type): "Unknown object type '\(type)'"
            case .invalidStructuralType: "Invalid structural type"
            case let .structuralTypeMismatch(type): "Structural type mismatch for type '\(type)'"

            // Frame-specific
            case let .unknownSnapshotID(id): "Unknown snapshot ID '\(id)'"
            case let .duplicateObject(id): "Duplicate object '\(id)'"
            case let .brokenStructuralIntegrity(error): "Broken structural integrity: \(error)"

            // Hierarchy
            case .unknownParent: "Unknown parent"
            case .childrenMismatch: "Children mismatch"

            case let .duplicateName(name): "Duplicate name '\(name)'"
            }
        }
        
        public var hint: String? {
            switch self {
            case .unknownEntityType(_): nil
            case .unknownID(_): nil

            // Identity reservation
            case .reservationConflict(_,_): "Try different identity strategy or check entity references"
            case .duplicateForeignID(_): "Make sure that the ID is unique"

            // Snapshot-specific
            case .missingObjectType: "Provide a correct object type name according to the metamodel the design conforms to"
            case .unknownObjectType(_): "Check design metamodel for available object types"
            case .invalidStructuralType,
                 .structuralTypeMismatch(_):  "Check foreign/raw design format documentation"

            // Frame-specific
            case .unknownSnapshotID(_): "Make sure all references are valid within the loaded raw design/snapshots"
            case .duplicateObject(_): "Object ID must be unique in the frame"
            case .brokenStructuralIntegrity(_): "The loaded batch is either of a different version, different metamodel or it is corrupted"

            // Hierarchy
            case .unknownParent: nil
            case .childrenMismatch: nil

            case .duplicateName(_): nil
            }
        }


    }
    
    public enum DesignError: Error, Equatable, Sendable, CustomStringConvertible {
        case missingCurrentFrame
        case namedReferenceTypeMismatch(String)
        case unknownFrameID(ForeignEntityID)
        
        public var description: String {
            switch self {
            case .missingCurrentFrame: "Current frame property is not specified in the raw design"
            case .namedReferenceTypeMismatch(let name): "Named reference '\(name)' is of different type than existing ID"
            case .unknownFrameID(let id): "Unknown frame ID '\(id)'"
            }
        }
        
        public var hint:String? { nil }

    }
}
