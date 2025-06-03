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
        let snapshotID: ObjectID
        let objectID: ObjectID
        
        let parent: ObjectID?
        
        /// List of resolved children IDs.
        ///
        /// If the property is `nil`, then it means that the children were not yet resolved.
        /// If the property is not `nil`, then any subsequent resolution of children must match
        /// the existing list of children, otherwise it means that the foreign data do not have
        /// referential integrity.
        let children: [ObjectID]?
        
        internal init(snapshotID: ObjectID, objectID: ObjectID, parent: ObjectID? = nil, children: [ObjectID]? = nil) {
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
        let frameID: ObjectID
        let snapshotIndices: [Int]?
        
        internal init(frameID: ObjectID, snapshotIndices: [Int]? = nil) {
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
    var snapshotIndex: [ObjectID:Int]
    /// Allocated identities of snapshots, in order of their occurrence.
    var resolvedSnapshots: [ResolvedSnapshot]
    
    var stableSnapshots: [ObjectSnapshot]
    
    let rawFrames: [RawFrame]
    /// Allocated identities of frames, in order of their occurrence.
    ///
    /// - SeeAlso: ``frameSnapshots``.
    var resolvedFrames: [ResolvedFrame]
    
    /// All IDs reserved using this reservation.
    var reserved: Set<ObjectID>
    
    /// Mapping between raw object IDs and allocated IDs
    var rawMap: [RawObjectID:ObjectID]
    
    
    /// Create a new Identity reservation that is bound to a design.
    ///
    init(design: Design, rawDesign: RawDesign? = nil, identityStrategy: DesignLoader.IdentityStrategy = .requireProvided) {
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
        
        self.reserved = Set()
        self.rawMap = [:]
        
        self.resolvedSnapshots = []
        self.resolvedFrames = []
        self.snapshotIndex = [:]
        self.stableSnapshots = []
    }
    
    public func contains(_ id: ObjectID) -> Bool {
        reserved.contains(id)
    }
    
    /// Get object ID and its type for given raw object ID, if it exists in the reservation.
    public subscript(_ rawID: RawObjectID) -> (id: ObjectID, type: IdentityType)? {
        if let actualID = rawMap[rawID], let type = design.identityManager.type(actualID) {
            return (id: actualID, type: type)
        }
        //        else if let actualID = ObjectID(rawID), reserved.contains(actualID),
        //           let type = design.identityManager.type(actualID) {
        //            return (id: actualID, type: type)
        //        }
        else {
            return nil
        }
    }
    
    internal func reserve(snapshotID rawSnapshotID: RawObjectID?, objectID rawObjectID: RawObjectID?) throws (RawIdentityError) {
        let snapshotID: ObjectID
        let objectID: ObjectID
        snapshotID = try reserveUnique(id: rawSnapshotID, type: .snapshot)
        objectID = try reserveIfNeeded(id: rawObjectID, type: .object)
        snapshotIndex[snapshotID] = resolvedSnapshots.count
        resolvedSnapshots.append(ResolvedSnapshot(snapshotID: snapshotID, objectID: objectID))
    }
    
    internal func reserve(frameID rawSnapshotID: RawObjectID?) throws (RawIdentityError) {
        let id = try reserveUnique(id: rawSnapshotID, type: .frame)
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
    @discardableResult
    internal func reserveUnique(id rawID: RawObjectID?, type: IdentityType) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        if let rawID {
            switch (identityStrategy, ObjectID(rawID)) {
            case (.requireProvided, .some(let id)):
                guard design.identityManager.reserve(id, type: type) else {
                    throw .duplicateID(rawID)
                }
                reservedID = id
            case (.requireProvided, .none):
                guard rawMap[rawID] == nil else {
                    throw .duplicateID(rawID)
                }
                reservedID = design.identityManager.createAndReserve(type: type)
            case (.preserveOrCreate, .some(let id)):
                if design.identityManager.reserve(id, type: type) {
                    reservedID = id
                }
                else {
                    reservedID = design.identityManager.createAndReserve(type: type)
                }
            case (.preserveOrCreate, .none),
                 (.createNew, _):
                reservedID = design.identityManager.createAndReserve(type: type)
            }
            rawMap[rawID] = reservedID
        }
        else {
            reservedID = design.identityManager.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }

    /// Reserve an ID of given type, if not already reserved.
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
    @discardableResult
    internal func reserveIfNeeded(id rawID: RawObjectID?, type: IdentityType) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        if let rawID {
            switch (identityStrategy, rawMap[rawID], ObjectID(rawID)) {
            case (.requireProvided, .some(let existingID), _):
                guard design.identityManager.type(existingID) == type else {
                    throw .typeMismatch(rawID)
                }
                reservedID = existingID

            case (.requireProvided, .none, .some(let id)):
                guard design.identityManager.reserveIfNeeded(id, type: type) else {
                    throw .typeMismatch(rawID)
                }
                reservedID = id
                rawMap[rawID] = reservedID

            case (.preserveOrCreate, .some(let existingID), _):
                if design.identityManager.type(existingID) == type {
                    reservedID = existingID
                }
                else {
                    reservedID = design.identityManager.createAndReserve(type: type)
                }

            case (.preserveOrCreate, .none, .some(let id)):
                if design.identityManager.reserveIfNeeded(id, type: type) {
                    reservedID = id
                }
                else {
                    reservedID = design.identityManager.createAndReserve(type: type)
                }

            case (.requireProvided, .none, .none),
                 (.preserveOrCreate, .none, .none),
                 (.createNew, _, _):
                reservedID = design.identityManager.createAndReserve(type: type)
            }
            rawMap[rawID] = reservedID
        }
        else {
            reservedID = design.identityManager.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }
}
