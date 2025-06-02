//
//  IdentityReservation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 07/05/2025.
//

/// Error thrown by the ``IdentityReservation``.
///
public enum RawIdentityError: Error, Equatable {
    case duplicateID(RawObjectID)
    case typeMismatch(RawObjectID)
}

/// Identity reservation provides functionality to reserve IDs within a single transaction.
///
/// Intended use of the identity reservation is during loading process from foreign (raw) sources.
///
/// The identity reservation is bound to a design and uses its ``IdentityManager`` for reservations.
///
public class LoadingContext {
    var state: State = .empty
    enum State: Int {
        case empty
        case initialized
        case identitiesReserved
        case referencesResolved
        case snapshotsCreated
        case closed
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
    init(design: Design, rawDesign: RawDesign? = nil) {
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
        if let actualID = ObjectID(rawID), reserved.contains(actualID),
           let type = design.identityManager.type(actualID) {
            return (id: actualID, type: type)
        }
        else {
            if let actualID = rawMap[rawID], let type = design.identityManager.type(actualID) {
                return (id: actualID, type: type)
            }
            else {
                return nil
            }
        }
    }
    
    internal func reserve(snapshotID rawSnapshotID: RawObjectID?, objectID rawObjectID: RawObjectID?) throws (RawIdentityError) {
        let snapshotID = try reserveUnique(id: rawSnapshotID, type: .snapshot)
        let objectID = try reserveIfNeeded(id: rawObjectID, type: .object)
        snapshotIndex[snapshotID] = resolvedSnapshots.count
        resolvedSnapshots.append(ResolvedSnapshot(snapshotID: snapshotID, objectID: objectID))
    }

    internal func reserve(frameID rawSnapshotID: RawObjectID?) throws (RawIdentityError) {
        let id = try reserveUnique(id: rawSnapshotID, type: .frame)
        resolvedFrames.append(ResolvedFrame(frameID: id))
    }

    /// Reserve an ID for entity of given type.
    ///
    /// The function tries to reserve an unique identity for given raw ID.
    /// - Raw ID is `nil`: new identity will be created and reserved
    /// - Raw ID is represents (is convertible to) an ``ObjectID``: Tries to reserve given ID, if
    ///   ID already exists, regardless of type, then it throws ``RawIdentityError/duplicateID(_:)``.
    /// - Raw ID is not a valid Object ID - is a custom name: If the raw ID is not be already
    ///   reserved (contained in the raw ID map), then a new one is created, reserved and registered
    ///   in the map. Otherwise ``RawIdentityError/duplicateID(_:)`` is thrown.
    ///
    @discardableResult
    internal func reserveUnique(id rawID: RawObjectID?, type: IdentityType) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        if let rawID {
            if let id = ObjectID(rawID) {
                guard design.identityManager.reserve(id, type: type) else {
                    throw .duplicateID(rawID)
                }
                reservedID = id
            }
            else {
                guard rawMap[rawID] == nil else {
                    throw .duplicateID(rawID)
                }
                reservedID = design.identityManager.createAndReserve(type: type)
                rawMap[rawID] = reservedID
            }
        }
        else {
            reservedID = design.identityManager.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }
    @discardableResult
    internal func create(id rawID: RawObjectID?, type: IdentityType) -> ObjectID {
        let reservedID: ObjectID
        if let rawID {
            reservedID = design.identityManager.createAndReserve(type: type)
            rawMap[rawID] = reservedID
        }
        else {
            reservedID = design.identityManager.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }

    @discardableResult
    internal func createIfNeeded(id rawID: RawObjectID?, type: IdentityType) -> ObjectID {
        let reservedID: ObjectID
        if let rawID {
            if let id = rawMap[rawID] {
                return id
            }
            else {
                reservedID = design.identityManager.createAndReserve(type: type)
                rawMap[rawID] = reservedID
            }
        }
        else {
            reservedID = design.identityManager.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }

    /// Rules
    /// - Must not exist within this reservation
    ///
    /// Reserve an ID for entity of given type.
    ///
    /// If there is no such ID a new one will be reserved. If there is already an ID for given
    /// raw ID then it will be returned if the types are matching.
    ///
    /// - Throws: ``RawIdentityError``
    ///
    @discardableResult
    internal func reserveIfNeeded(id rawID: RawObjectID?, type: IdentityType) throws (RawIdentityError) -> ObjectID {
        let reservedID: ObjectID
        if let rawID {
            if let id = rawMap[rawID] {
                guard design.identityManager.type(id) == type else {
                    throw .typeMismatch(rawID)
                }
                reservedID = id
            }
            else if let id = ObjectID(rawID) {
                guard design.identityManager.reserveIfNeeded(id, type: type) else {
                    throw .typeMismatch(rawID)
                }
                reservedID = id
            }
            else {
                reservedID = design.identityManager.createAndReserve(type: type)
                rawMap[rawID] = reservedID
            }
        }
        else {
            reservedID = design.identityManager.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }
}
