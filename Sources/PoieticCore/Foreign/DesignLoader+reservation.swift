//
//  DesignLoader+reservation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 14/10/2025.
//

extension DesignLoader { // Reservation of identities

    /// Reserves identities for entities in the raw design, such as snapshots, objects and frames.
    ///
    /// The identities are reserved according to the identity strategy
    /// (``DesignLoader.IdentityStrategy``).
    ///
    /// Strategy
    /// - Snapshot ID, Frame ID:
    ///     - some provided: ID will be reserved if available, if not then duplicate error is thrown.
    ///     - `nil`: New ID will be created and reserved, snapshot will be considered an orphan.
    /// - Object ID:
    ///     - some provided: ID will be reserved if available. If it is already used, it must be
    ///       an object ID, otherwise type mismatch error is thrown.
    ///     - `nil`: New ID will be created and reserved.
    ///
    /// You typically do not need to call this method, it is called in ``load(_:)``
    /// and ``load(_:into:)-1o6qf``. It is provided for more customised loading.
    ///
    /// ## Orphans
    ///
    /// If ID is not provided, it will be generated. However, that object is considered an orphan
    /// and it will not be able to refer to it from other entities.
    ///
    /// Orphaned snapshots will be ignored. Objects with orphaned object identity will be preserved.
    ///
    /// - Precondition: The context must be in the initialization phase.
    internal func resolveIdentities(context: ValidatedLoadingContext,
                                    identityStrategy: IdentityStrategy,
                                    unavailableIDs: Set<EntityID.RawValue> = Set())
        throws (DesignLoaderError) -> IdentityResolution
    {
        var reservation = ReservationContext(unavailableIDs: unavailableIDs)
        
        // Reservation Phase 1: Reserve those IDs we can
        switch identityStrategy {
        case .createNew:
            break // Nothing to create, all identities will be new
        case .preserveOrCreate:
            try reserveIdentitiesWithAutoStrategy(context, reservation: &reservation)
        case .requireProvided:
            try reserveIdentitiesWithRequireStrategy(context, reservation: &reservation)
        }

        // Reservation Phase 2: Create those IDs we do not have
        let rawFrameIDs = context.rawFrames.map { $0.id }
        let rawSnapshotIDs = context.rawSnapshots.map { $0.snapshotID }
        let rawObjectIDs = context.rawSnapshots.map { $0.objectID }

        let frameIDs: [FrameID] = finaliseReservation(
            ids: rawFrameIDs,
            reservation: &reservation,
            identityManager: context.identityManager
        )
        let snapshotIDs: [ObjectSnapshotID] = finaliseReservation(
            ids: rawSnapshotIDs,
            reservation: &reservation,
            identityManager: context.identityManager
        )
        let objectIDs: [ObjectID] = finaliseReservation(
            ids: rawObjectIDs,
            reservation: &reservation,
            identityManager: context.identityManager
        )

        // Sanity checks
        assert(frameIDs.count == rawFrameIDs.count)
        assert(snapshotIDs.count == rawSnapshotIDs.count)
        assert(objectIDs.count == rawObjectIDs.count)

        // Create snapshot index – used for resolving frames and hierarchy
        var snapshotIndex: [ObjectSnapshotID:Int] = [:]
        for (index, id) in snapshotIDs.enumerated() {
            assert(snapshotIndex[id] == nil, "Duplicate snapshot ID \(id)")
            snapshotIndex[id] = index
        }

        return IdentityResolution(
            reserved: reservation.reserved,
            rawIDMap: reservation.rawIDMap,
            frameIDs: frameIDs,
            snapshotIDs: snapshotIDs,
            objectIDs: objectIDs,
            snapshotIndex: snapshotIndex
        )
    }
    
    internal func reserveIdentitiesWithAutoStrategy(_ context: ValidatedLoadingContext,
                                                    reservation: inout ReservationContext)
        throws (DesignLoaderError)
    {
        let frameIDs = context.rawFrames.compactMap { $0.id }
        let snapshotIDs = context.rawSnapshots.compactMap { $0.snapshotID }
        let objectIDs = context.rawSnapshots.compactMap { $0.objectID }

        reserveAvailable(ids: frameIDs,
                         type: .frame,
                         reservation: &reservation,
                         identityManager: context.identityManager)
        reserveAvailable(ids: snapshotIDs,
                         type: .frame,
                         reservation: &reservation,
                         identityManager: context.identityManager)
        reserveAvailableObjectIDs(ids: objectIDs,
                         type: .frame,
                         reservation: &reservation,
                         identityManager: context.identityManager)
    }

    internal func reserveIdentitiesWithRequireStrategy(_ context: ValidatedLoadingContext,
                                                       reservation: inout ReservationContext)
        throws (DesignLoaderError)
    {
        let rawFrameIDs = context.rawFrames.map { $0.id }
        let rawSnapshotIDs = context.rawSnapshots.map { $0.snapshotID }
        let rawObjectIDs = context.rawSnapshots.map { $0.objectID }

        // Reservation Phase 1: Reserve those IDs we can
        do {
            try reserveRequired(
                ids: rawSnapshotIDs,
                type: .objectSnapshot,
                reservation: &reservation,
                identityManager: context.identityManager
            )
        }
        catch {
            throw .item(.objectSnapshots, error.index, error.error)
        }

        do {
            try reserveRequired(
                ids: rawFrameIDs,
                type: .frame,
                reservation: &reservation,
                identityManager: context.identityManager
            )
        }
        catch {
            throw .item(.frames, error.index, error.error)
        }

        do {
            try reserveRequiredObjectIDs(
                ids: rawObjectIDs,
                reservation: &reservation,
                identityManager: context.identityManager
            )
        }
        catch {
            throw .item(.objectSnapshots, error.index, error.error)
        }
    }

    /// Reserve IDs from the list of foreign IDs if possible.
    ///
    /// Only IDs that are convertible to ``EntityID/RawValue`` are considered, non-convertible
    /// are ignored.
    ///
    /// The reserved ID is stored in the context ID map (``LoadingContext/rawIDMap``)
    ///
    internal func reserveAvailable(
        ids foreignIDs: some Collection<ForeignEntityID>,
        type: IdentityType,
        reservation: inout ReservationContext,
        identityManager: IdentityManager)
    {
        for foreignID in foreignIDs {
            guard let rawValue = foreignID.rawEntityIDValue else { continue }
            if identityManager.reserve(rawValue, type: type) {
                precondition(reservation.rawIDMap[foreignID] == nil) // Validation failed
                reservation.rawIDMap[foreignID] = rawValue
                reservation.reserved.append(rawValue)
            }
        }
    }

    internal func reserveAvailableObjectIDs(
        ids foreignIDs: some Collection<ForeignEntityID>,
        type: IdentityType,
        reservation: inout ReservationContext,
        identityManager: IdentityManager)
    {
        for foreignID in foreignIDs {
            guard let rawValue = foreignID.rawEntityIDValue else { continue }
            guard !reservation.unavailableIDs.contains(rawValue) else { continue }
            
            if identityManager.reserveIfNeeded(ObjectID(rawValue: rawValue)) {
                precondition(reservation.rawIDMap[foreignID] == nil) // Validation failed
                reservation.rawIDMap[foreignID] = rawValue
                reservation.reserved.append(rawValue)
            }
        }
    }

    /// Reserve IDs from the list of foreign IDs if possible.
    ///
    /// Only IDs that are convertible to ``EntityID/RawValue`` are considered, non-convertible
    /// are ignored.
    ///
    /// - Returns: `nil` if all possible reservations went through, otherwise an index of first ID
    ///   that is convertible but can not be reserved.
    ///
    internal func reserveRequired(
        ids foreignIDs: some Collection<ForeignEntityID?>,
        type: IdentityType,
        reservation: inout ReservationContext,
        identityManager: IdentityManager)
    throws (DesignLoaderError.IndexedItemError)
    {
        // TODO: Rethink the error signalling. Returning first offensive seems a bit weird and not very intuitive.
        for (index, foreignID) in foreignIDs.enumerated() {
            guard let foreignID,
                  let rawValue = foreignID.rawEntityIDValue
            else { continue }
            
            precondition(reservation.rawIDMap[foreignID] == nil, "Failed validation")

            guard identityManager.reserve(rawValue, type: type) else {
                throw DesignLoaderError.IndexedItemError(index, .reservationConflict(type, foreignID))
            }
            reservation.rawIDMap[foreignID] = rawValue
            reservation.reserved.append(rawValue)
        }
    }
    
    /// Reserve IDs as object IDs from the list of foreign IDs if possible.
    ///
    /// Only IDs that are convertible to ``EntityID/RawValue`` are considered, non-convertible
    /// are ignored.
    ///
    /// Foreign IDs that are contained in the unavailable list (``LoadingContext/unavailableIDs``)
    /// do not satisfy requirement for reservation.
    ///
    /// Otherwise the foreign ID will be ignored.
    ///
    /// - Returns: `nil` if all possible reservations went through, otherwise an index of first ID
    ///   that is convertible but can not be reserved.
    ///
    internal func reserveRequiredObjectIDs(
        ids foreignIDs: some Collection<ForeignEntityID?>,
        reservation: inout ReservationContext,
        identityManager: IdentityManager)
    throws (DesignLoaderError.IndexedItemError)
    {
        for (index, foreignID) in foreignIDs.enumerated() {
            guard let foreignID,
                  let rawValue = foreignID.rawEntityIDValue
            else { continue }
            
            precondition(reservation.rawIDMap[foreignID] == nil, "Failed validation")

            guard !reservation.unavailableIDs.contains(rawValue),
                  identityManager.reserve(rawValue, type: .object) else {
                throw DesignLoaderError.IndexedItemError(index, .reservationConflict(.object, foreignID))
            }
            reservation.rawIDMap[foreignID] = rawValue
            reservation.reserved.append(rawValue)
        }
    }

    /// Reserve IDs from the list of foreign IDs if possible.
    ///
    /// Only IDs that are convertible to ``EntityID/RawValue`` are considered, non-convertible
    /// are ignored.
    ///
    /// - Returns: `nil` if all possible reservations went through, otherwise an index of first ID
    ///   that is convertible but can not be reserved.
    ///
    @discardableResult
    internal func finaliseReservation<T>(
        ids foreignIDs: some Collection<ForeignEntityID?>,
        reservation: inout ReservationContext,
        identityManager: IdentityManager) -> [EntityID<T>]
    {
        var result: [EntityID<T>] = []
        
        for foreignID in foreignIDs {
            let id: EntityID<T>
            if let foreignID {
                if let reservedID = reservation.rawIDMap[foreignID] {
                    assert(identityManager.type(reservedID) == T.identityType)
                    id = EntityID(rawValue: reservedID)
                }
                else {
                    id = identityManager.reserveNew()
                    reservation.rawIDMap[foreignID] = id.rawValue
                    reservation.reserved.append(id.rawValue)
                }
            }
            else {
                id = identityManager.reserveNew()
                reservation.reserved.append(id.rawValue)
            }
            result.append(id)
        }
        return result
    }

}
