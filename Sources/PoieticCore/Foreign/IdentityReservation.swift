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
public struct IdentityReservation: ~Copyable {
    /// Design that the identity reservation is bound to.
    public let design: Design

    /// All IDs reserved using this reservation.
    var reserved: Set<ObjectID>
    
    /// Mapping between raw object IDs and allocated IDs
    var rawMap: [RawObjectID:ObjectID]

    /// Allocated identities of snapshots, in order of their occurrence.
    var snapshots: [(ObjectID, ObjectID)]

    /// Allocated identities of frames, in order of their occurrence.
    var frames: [ObjectID]
    
    /// Create a new Identity reservation that is bound to a design.
    ///
    init(design: Design) {
        self.design = design
        self.snapshots = []
        self.frames = []
        self.rawMap = [:]
        self.reserved = Set()
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
    
    mutating func reserve(snapshotID rawSnapshotID: RawObjectID?, objectID rawObjectID: RawObjectID?) throws (RawIdentityError) {
        let snapshotID = try reserveUnique(id: rawSnapshotID, type: .snapshot)
        let objectID = try reserveIfNeeded(id: rawObjectID, type: .object)
        snapshots.append((snapshotID, objectID))
    }

    mutating func create(snapshotID rawSnapshotID: RawObjectID?, objectID rawObjectID: RawObjectID?) {
        let snapshotID = create(id: rawSnapshotID, type: .snapshot)
        let objectID = createIfNeeded(id: rawObjectID, type: .object)
        snapshots.append((snapshotID, objectID))
    }

    mutating func reserve(frameID rawSnapshotID: RawObjectID?) throws (RawIdentityError) {
        let id = try reserveUnique(id: rawSnapshotID, type: .frame)
        frames.append(id)
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
    mutating func reserveUnique(id rawID: RawObjectID?, type: IdentityType) throws (RawIdentityError) -> ObjectID {
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
    mutating func create(id rawID: RawObjectID?, type: IdentityType) -> ObjectID {
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
    mutating func createIfNeeded(id rawID: RawObjectID?, type: IdentityType) -> ObjectID {
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
    mutating func reserveIfNeeded(id rawID: RawObjectID?, type: IdentityType) throws (RawIdentityError) -> ObjectID {
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
