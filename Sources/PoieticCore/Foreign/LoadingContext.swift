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
    /// Requested ID is already registered, regardless of type.
    case duplicateID
    /// Requested ID is already registered and its type is different type.
    case typeMismatch
    
    public var description: String {
        switch self {
        case .duplicateID: "Duplicate ID"
        case .typeMismatch: "Entity ID type mismatch"
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


/// Identity reservation provides functionality to reserve IDs within a single transaction.
///
/// Intended use of the identity reservation is during loading process from foreign (raw) sources.
///
/// The identity reservation is bound to a design and uses its ``IdentityManager`` for reservations.
///
public class LoadingContext {
    
    // TODO: Use phases and include them in the Loader.
    public enum Phase {
        /// Initial phase of loading.
        ///
        /// - Inputs assigned.
        /// - Nothing has been validated.
        /// - No identities allocated.
        /// - No results created.
        case initial
        
        /// The raw design is valid.
        ///
        /// - Snapshot and frame identities contain no duplicates.
        ///
        /// - SeeAlso: ``DesignLoader/validate(context:)``
        ///
        case validated
        
        /// Identities are reserved.
        ///
        /// - All identities were reserved or created, depending on the strategy.
        /// - ID map contains mapping of foreign identities to their respective ID values.
        /// - Resolved snapshots are created and prepared without children/parent relationships.
        ///
        case identitiesReserved
        case objectSnapshotsResolved
        case framesResolved
        case hierarchyResolved
        case objectsCreated
    }
    
    // TODO: Pick a better name or split to snapshot/hierarchy
    struct ResolvedObjectSnapshot {
        /// Final object snapshot ID.
        ///
        /// If the phase is `Phase/empty` then the property contains an ID that is being requested.
        /// Actual reserved ID will depend on the identity strategy.
        ///
        let snapshotID: ObjectSnapshotID
        /// Requested or reserved object ID.
        ///
        /// If the phase is `Phase/empty` then the property contains an ID that is being requested.
        /// Actual reserved ID will depend on the identity strategy.
        ///
        let objectID: ObjectID
        let structureReferences: [ObjectID]
        
        let parent: ObjectID?
        
        /// List of resolved children IDs.
        ///
        /// If the property is `nil`, then it means that the children were not yet resolved.
        /// If the property is not `nil`, then any subsequent resolution of children must match
        /// the existing list of children, otherwise it means that the foreign data do not have
        /// referential integrity.
        var children: [ObjectID]?
        
        internal init(snapshotID: ObjectSnapshotID,
                      objectID: ObjectID,
                      structureReferences: [ObjectID] = [],
                      parent: ObjectID? = nil,
                      children: [ObjectID]? = nil) {
            self.snapshotID = snapshotID
            self.objectID = objectID
            self.structureReferences = structureReferences
            self.parent = parent
            self.children = children
        }
    }
    
    struct ResolvedFrame {
        let frameID: FrameID
        let snapshotIndices: [Int]
        
        internal init(frameID: FrameID, snapshotIndices: [Int]) {
            self.frameID = frameID
            self.snapshotIndices = snapshotIndices
        }
    }
    
    // MARK: State, Config and Target
    
    var phase: Phase

    /// Design that the loading context is bound to.
    let design: Design
    
    /// Frame into which the loading occurs
    let frame: TransientFrame?

    // FIXME: Remove, keep in loader
    let identityStrategy: DesignLoader.IdentityStrategy

    // MARK: Inputs
    
    let rawSnapshots: [RawSnapshot]
    let rawFrames: [RawFrame]

    /// IDs that are unavailable for their use or reservation, regardless of their actual
    /// reservation status.
    ///
    /// Used in `reserveIfNeeded`.
    ///
    var unavailableIDs: Set<EntityID.RawValue>


    // MARK: Intermediate Products
    // Phase 1: Reserve Identities

    /// All IDs reserved using this reservation.
    ///
    /// The loader or other user's of the context is responsible for either marking the reserved
    /// identities as used or releasing them.
    ///
    var reserved: [EntityID.RawValue]

    /// Mapping between raw IDs and allocated IDs
    var rawIDMap: [ForeignEntityID:EntityID.RawValue]
    
    // MARK: Reservation Results
    var frameIDs: [FrameID]?
    var snapshotIDs: [ObjectSnapshotID]?
    var objectIDs: [ObjectID]?

    /// Snapshot ID to snapshot index.
    var snapshotIndex: [ObjectSnapshotID:Int]

    // ------
    
    /// Identities of snapshots, objects and their relationships that has been resolved.
    var resolvedSnapshots: [ResolvedObjectSnapshot]?

    /// Allocated identities of frames, in order of their occurrence.
    ///
    /// - SeeAlso: ``frameSnapshots``.
    var resolvedFrames: [ResolvedFrame]?

    // MARK: Outputs
    
    /// Snapshots created from the raw snapshots.
    var objectSnapshots: [ObjectSnapshot]?
    
    
    
    
    /// Create a new Identity reservation that is bound to a design.
    ///
    /// Use of `unavailable` parameter:
    ///
    /// - Paste: `unavailable: Set(frame.objectIDs)`
    /// - Import avoiding specific IDs: `unavailable: Set([id1, id2, id3])`
    /// - Complex merging scenarios: `unavailable: existingModel.allObjectIDs.union(reservedIDs)`
    ///
    init(design: Design,
         rawDesign: RawDesign? = nil,
         frame: TransientFrame? = nil,
         identityStrategy: DesignLoader.IdentityStrategy = .requireProvided,
         unavailable: Set<ObjectID> = Set()) {
        // Initialise State, config, target
        //
        
        self.phase = .initial
        self.design = design
        self.frame = frame
        
        self.identityStrategy = identityStrategy

        // Initialise Inputs
        //
        if let rawDesign {
            self.rawSnapshots = rawDesign.snapshots
            self.rawFrames = rawDesign.frames
        }
        else {
            self.rawSnapshots = []
            self.rawFrames = []
        }
        self.unavailableIDs = Set(unavailable.map { $0.rawValue })

        // Initialise Intermediate Products
        //

        self.reserved = []
        self.rawIDMap = [:]
        self.resolvedSnapshots = []
        self.resolvedFrames = []
        self.snapshotIndex = [:]

        // Initialise Outputs
        self.objectSnapshots = []
    }
    
    public func contains<T>(_ id: EntityID<T>) -> Bool {
        reserved.contains(id.rawValue)
    }
    
    /// Get object ID and its type for given raw object ID, if it exists in the reservation.
//    public subscript<T>(_ rawID: RawObjectID) -> EntityID<T>? {
//        guard let value = rawIDMap[rawID] else { return nil }
//        let id = EntityID<T>(value)
//        assert(reserved.contains(value))
//        assert(design.identityManager.contains(id))
//
//        return id
//    }
    // TODO: Rename to explicit resolveID or validatedID or reservedID or something like that
    public func getID(_ rawID: ForeignEntityID, type: IdentityType) -> EntityID.RawValue? {
        guard let value = rawIDMap[rawID],
              design.identityManager.type(value) == type
        else {
            return nil
        }
        return value
    }

    public func getID<T>(_ rawID: ForeignEntityID) -> EntityID<T>? {
        guard let value = rawIDMap[rawID],
              design.identityManager.type(value) == T.identityType
        else {
            return nil
        }
        return EntityID(rawValue: value)
    }
}

public class LoaderIdentityReservation {
    let foreignFrameIDs: [ForeignEntityID]
    let foreignSnapshotIDs: [ForeignEntityID]
    let foreignObjectIDs: [ForeignEntityID]
    let unavailable: Set<EntityID.RawValue>

    var reserved: [EntityID.RawValue]
    var foreignToReserved: [ForeignEntityID:EntityID.RawValue]
    
    public init(frameIDs: [ForeignEntityID] = [],
                snapshotIDs: [ForeignEntityID] = [],
                objectIDs: [ForeignEntityID] = [],
                unavailable: Set<EntityID.RawValue> = []) {
        self.foreignFrameIDs = frameIDs
        self.foreignSnapshotIDs = snapshotIDs
        self.foreignObjectIDs = objectIDs

        self.unavailable = unavailable
        self.foreignToReserved = [:]

        self.reserved = []
    }
    
}
