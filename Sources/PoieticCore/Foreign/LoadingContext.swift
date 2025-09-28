//
//  IdentityReservation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 07/05/2025.
//

/// Error thrown by the ``IdentityReservation``.
///
public enum RawIdentityError: Error, Equatable, CustomStringConvertible {
    case duplicateID(RawObjectID)
    case typeMismatch(RawObjectID)
    
    public var description: String {
        switch self {
        case .duplicateID(let id): "Duplicate ID '\(id)'"
        case .typeMismatch(let id): "Entity type mismatch for ID '\(id)'"
        }
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
    enum Phase {
        case identitiesReserved
        case referencesResolved
        case objectsCreated
    }
    
    struct ResolvedSnapshot {
        let snapshotID: ObjectSnapshotID
        let objectID: ObjectID
        
        let parent: ObjectID?
        
        /// List of resolved children IDs.
        ///
        /// If the property is `nil`, then it means that the children were not yet resolved.
        /// If the property is not `nil`, then any subsequent resolution of children must match
        /// the existing list of children, otherwise it means that the foreign data do not have
        /// referential integrity.
        let children: [ObjectID]?
        
        internal init(snapshotID: ObjectSnapshotID, objectID: ObjectID, parent: ObjectID? = nil, children: [ObjectID]? = nil) {
            self.snapshotID = snapshotID
            self.objectID = objectID
            self.parent = parent
            self.children = children
        }
        
        func copy(parent: ObjectID?=nil, children: [ObjectID]?=nil) -> ResolvedSnapshot {
            ResolvedSnapshot(
                snapshotID: self.snapshotID,
                objectID: self.objectID,
                parent: self.parent ?? parent,
                children: self.children ?? children
            )
        }
    }
    
    struct ResolvedFrame {
        let frameID: FrameID
        let snapshotIndices: [Int]?
        
        internal init(frameID: FrameID, snapshotIndices: [Int]? = nil) {
            self.frameID = frameID
            self.snapshotIndices = snapshotIndices
        }
        internal func copy(snapshotIndices: [Int]? = nil) -> ResolvedFrame{
            ResolvedFrame(frameID: self.frameID,
                          snapshotIndices: snapshotIndices)
        }
    }
    
    let identityStrategy: DesignLoader.IdentityStrategy
    
    /// Design that the loading context is bound to.
    let design: Design
    
    let rawSnapshots: [RawSnapshot]
    /// Snapshot ID to snapshot index.
    var snapshotIndex: [ObjectSnapshotID:Int]
    /// Allocated identities of snapshots, in order of their occurrence.
    var resolvedSnapshots: [ResolvedSnapshot]
    
    var stableSnapshots: [ObjectSnapshot]
    
    let rawFrames: [RawFrame]
    /// Allocated identities of frames, in order of their occurrence.
    ///
    /// - SeeAlso: ``frameSnapshots``.
    var resolvedFrames: [ResolvedFrame]
    
    /// All IDs reserved using this reservation.
    var reserved: Set<EntityID.RawValue>

    /// IDs that are unavailable for their use or reservation, regardless of their actual
    /// reservation status.
    ///
    /// Used in `reserveIfNeeded`.
    ///
    var unavailable: Set<ObjectID>
    
    /// Mapping between raw IDs and allocated IDs
    var knownIDMap: [RawObjectID:EntityID.RawValue]
    
    
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
         identityStrategy: DesignLoader.IdentityStrategy = .requireProvided,
         unavailable: Set<ObjectID> = Set()) {
        self.identityStrategy = identityStrategy
        self.design = design
        
        if let rawDesign {
            self.rawSnapshots = rawDesign.snapshots
            self.rawFrames = rawDesign.frames
        }
        else {
            self.rawSnapshots = []
            self.rawFrames = []
        }
        
        self.unavailable = unavailable
        self.reserved = Set()
        self.knownIDMap = [:]
        
        self.resolvedSnapshots = []
        self.resolvedFrames = []
        self.snapshotIndex = [:]
        self.stableSnapshots = []
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

    public func getID(_ rawID: RawObjectID, type: IdentityType) -> EntityID.RawValue? {
        guard let value = knownIDMap[rawID],
              design.identityManager.type(value) == type
        else {
            return nil
        }
        return value
    }

    public func getID<T>(_ rawID: RawObjectID) -> EntityID<T>? {
        guard let value = knownIDMap[rawID],
              design.identityManager.type(value) == T.identityType
        else {
            return nil
        }
        return EntityID(rawValue: value)
    }

    internal func reserve(snapshotID rawSnapshotID: RawObjectID?,
                          objectID rawObjectID: RawObjectID?) throws (RawIdentityError)
    {
        let snapshotID: ObjectSnapshotID = try reserveUnique(id: rawSnapshotID)
        let objectID: ObjectID = try reserveIfNeeded(id: rawObjectID)
        snapshotIndex[snapshotID] = resolvedSnapshots.count
        resolvedSnapshots.append(ResolvedSnapshot(snapshotID: snapshotID, objectID: objectID))
    }
    
    internal func reserve(frameID rawSnapshotID: RawObjectID?) throws (RawIdentityError) {
        let id: FrameID = try reserveUnique(id: rawSnapshotID)
        resolvedFrames.append(ResolvedFrame(frameID: id))
    }
    
    
    /// Reserve an ID of given type.
    ///
    /// If the raw ID is nil, then a new ID will be created and reserved. If the raw ID is provided,
    /// then the reservation is based on the ``DesignLoader/IdentityStrategy``:
    ///
    /// - `requireProvided`: provided ID must not be used nor reserved.
    /// - `createNew`: new ID will be created in any case, raw ID will be used only for look-up
    /// - `preserveIfPossible`: if ID is free, then it will be reserved, otherwise a new one will
    ///   be created.
    ///
    /// - Throws: ``RawIdentityError/duplicateID(_:)`` when requiring a concrete ID and the ID is
    ///   already used or reserved.
    ///
    @discardableResult
    internal func reserveUnique<T>(id rawID: RawObjectID?) throws (RawIdentityError) -> EntityID<T> {
        let reservedID: EntityID<T>

        guard let rawID else {
            reservedID = design.identityManager.reserveNew()
            reserved.insert(reservedID.rawValue)
            return reservedID
        }
        
        // Test for identity strategy and attempt to convert the raw ID into actual ID
        switch (identityStrategy, EntityID<T>(rawID)) {
        case (.requireProvided, .some(let id)):
            guard design.identityManager.reserve(id) else {
                throw .duplicateID(rawID)
            }
            reservedID = id
            
        case (.requireProvided, .none):
            // Not directly convertible, for example a string
            guard knownIDMap[rawID] == nil else {
                throw .duplicateID(rawID)
            }
            reservedID = design.identityManager.reserveNew()

        case (.preserveOrCreate, .some(let id)):
            if design.identityManager.reserve(id) {
                reservedID = id
            }
            else {
                reservedID = design.identityManager.reserveNew()
            }

        case (.preserveOrCreate, .none),
             (.createNew, _):
            reservedID = design.identityManager.reserveNew()
        }
        knownIDMap[rawID] = reservedID.rawValue
        reserved.insert(reservedID.rawValue)
        return reservedID
    }

    /// Reserve an object ID, if not already reserved.
    ///
    /// If the raw ID is nil, then a new ID will be created and reserved. If the raw ID is provided,
    /// then the reservation is based on the ``DesignLoader/IdentityStrategy``:
    ///
    /// - `requireProvided`: If ID is free, then it will be used. If the ID is used, it must be of
    ///   the required type, otherwise a type-mismatch error is thrown.
    /// - `createNew`: new ID will be created in any case, raw ID will be used only for look-up
    /// - `preserveOrCreate`: If ID is free, then it will be reserved. If ID is used and is of
    ///   different type, then new one will be created. If it is used and of the same type, then
    ///   nothing happens.
    ///
    /// - Throws: ``RawIdentityError/typeMismatch(_:)`` when trying to reserve an ID that is already
    ///   used or reserved but is of a different entity type.
    ///
    @discardableResult
    internal func reserveIfNeeded(id rawID: RawObjectID?) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        guard let rawID else {
            reservedID = design.identityManager.reserveNew()
            reserved.insert(reservedID.rawValue)
            return reservedID
        }
        
        if let knownID = knownIDMap[rawID] {
            return try reserveIfNeeded(rawID: rawID, knownID: knownID)
        }
        else if let proposedID = ObjectID(rawID) { // Unknown ID, but convertible (non-string)
            return try reserveIfNeeded(rawID: rawID, proposedID: proposedID)
        }
        else { // rawID is not convertible to object ID
            reservedID = design.identityManager.reserveNew()
            knownIDMap[rawID] = reservedID.rawValue
        }
        
        reserved.insert(reservedID.rawValue)

        return reservedID
    }
    internal func reserveIfNeeded(rawID: RawObjectID, knownID: EntityID.RawValue) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        switch identityStrategy {
        case .requireProvided:
            guard design.identityManager.type(knownID) == .object else {
                throw .typeMismatch(rawID)
            }
            reservedID = ObjectID(rawValue: knownID)
        case .preserveOrCreate:
            if design.identityManager.type(knownID) == .object {
                reservedID = ObjectID(rawValue: knownID)
            }
            else {
                reservedID = design.identityManager.reserveNew()
                knownIDMap[rawID] = reservedID.rawValue
            }
        case .createNew:
            reservedID = design.identityManager.reserveNew()
            knownIDMap[rawID] = reservedID.rawValue
        }
        reserved.insert(reservedID.rawValue)

        return reservedID
    }
    internal func reserveIfNeeded(rawID: RawObjectID, proposedID: ObjectID) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        switch identityStrategy {
        case .requireProvided:
            guard design.identityManager.reserveIfNeeded(proposedID) else {
                throw .typeMismatch(rawID)
            }
            reservedID = proposedID
        case .preserveOrCreate:
            if unavailable.contains(proposedID) {
                reservedID = design.identityManager.reserveNew()
            }
            else if design.identityManager.reserveIfNeeded(proposedID) {
                reservedID = proposedID
            }
            else {
                reservedID = design.identityManager.reserveNew()
            }
        case .createNew:
            reservedID = design.identityManager.reserveNew()
        }
        knownIDMap[rawID] = reservedID.rawValue
        reserved.insert(reservedID.rawValue)

        return reservedID
    }
}
