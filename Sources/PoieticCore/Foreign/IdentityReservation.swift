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

/// Identity reservation provides functionality to reserve IDs for snapshots, objects, frames and
/// other design entities.
///
/// The identity reservation is bound to a design and uses its ``IdentityManager`` for reservations.
///
/// Intended use of the identity reservation is during loading process from foreign (raw) sources.
///
struct IdentityReservation: ~Copyable {
    /// Design that the identity reservation is bound to.
    let design: Design

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
    
    func contains(_ id: ObjectID) -> Bool {
        reserved.contains(id)
    }
    
    mutating func reserve(snapshotID rawSnapshotID: RawObjectID?, objectID rawObjectID: RawObjectID?) throws (RawIdentityError) {
        let snapshotID = try reserveUnique(id: rawSnapshotID, type: .snapshot)
        let objectID = try reserveIfNeeded(id: rawObjectID, type: .object)
        snapshots.append((snapshotID, objectID))

    }
    mutating func reserve(frameID rawSnapshotID: RawObjectID?) throws (RawIdentityError) {
        let id = try reserveUnique(id: rawSnapshotID, type: .snapshot)
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
                guard design.reserve(id: id, type: type) else {
                    throw .duplicateID(rawID)
                }
                reservedID = id
            }
            else {
                guard rawMap[rawID] == nil else {
                    throw .duplicateID(rawID)
                }
                reservedID = design.createAndReserve(type: type)
                rawMap[rawID] = reservedID
            }
        }
        else {
            reservedID = design.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }
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
                guard design.idType(id) == type else {
                    throw .typeMismatch(rawID)
                }
                reservedID = id
            }
            else if let id = ObjectID(rawID) {
                guard design.reserveIfNeeded(id: id, type: type) else {
                    throw .typeMismatch(rawID)
                }
                reservedID = id
            }
            else {
                reservedID = design.createAndReserve(type: type)
                rawMap[rawID] = reservedID
            }
        }
        else {
            reservedID = design.createAndReserve(type: type)
        }
        reserved.insert(reservedID)
        return reservedID
    }

    
    /// List of objects that have invalid or missing types. If design is migrated, this
    /// might be used as a source of information for setting the correct type. Otherwise
    /// non-empty array means an error.
    subscript(_ rawID: RawObjectID) -> (id: ObjectID, type: IdentityType)? {
        if let actualID = ObjectID(rawID), reserved.contains(actualID), let type = design.idType(actualID) {
            return (id: actualID, type: type)
        }
        else {
            if let actualID = rawMap[rawID], let type = design.idType(actualID) {
                return (id: actualID, type: type)
            }
            else {
                return nil
            }
        }
    }
}
