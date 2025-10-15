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
    public func reserveIdentities(_ context: LoadingContext) throws (DesignLoaderError) {
        precondition(context.phase == .validated)
        // Reservation Phase 1: Reserve those IDs we can
        switch context.identityStrategy {
        case .createNew:
            break // Nothing to create, all identities will be new
        case .preserveOrCreate:
            try reserveIdentitiesWithAutoStrategy(context)
        case .requireProvided:
            try reserveIdentitiesWithRequireStrategy(context)
        }

        // Reservation Phase 2: Create those IDs we do not have
        let rawFrameIDs = context.rawFrames.map { $0.id }
        let rawSnapshotIDs = context.rawSnapshots.map { $0.snapshotID }
        let rawObjectIDs = context.rawSnapshots.map { $0.objectID }

        context.frameIDs = finaliseReservation(context, ids: rawFrameIDs)
        context.snapshotIDs = finaliseReservation(context, ids: rawSnapshotIDs)
        context.objectIDs = finaliseReservation(context, ids: rawObjectIDs)

        assert(context.rawFrames.count == rawFrameIDs.count)
        assert(context.rawSnapshots.count == rawSnapshotIDs.count)
        assert(context.rawSnapshots.count == rawObjectIDs.count)

        // Create snapshot index – used for resolving frames and hierarchy
        var map: [ObjectSnapshotID:Int] = [:]
        for (index, id) in context.snapshotIDs!.enumerated() {
            assert(map[id] == nil)
            map[id] = index
        }
        
        context.phase == .identitiesReserved
    }
    
    internal func reserveIdentitiesWithAutoStrategy(_ context: LoadingContext)
        throws (DesignLoaderError)
    {
        precondition(context.phase == .validated)
        let rawFrameIDs = context.rawFrames.map { $0.id }
        let rawSnapshotIDs = context.rawSnapshots.map { $0.snapshotID }
        let rawObjectIDs = context.rawSnapshots.map { $0.objectID }

        reserveAvailable(context,
                         ids: rawFrameIDs.compactMap { $0 },
                         type: .frame)
        reserveAvailable(context,
                         ids: rawSnapshotIDs.compactMap { $0 },
                         type: .objectSnapshot)
        reserveAvailableObjectIDs(context,
                                  ids: rawObjectIDs.compactMap { $0 })
    }

    internal func reserveIdentitiesWithRequireStrategy(_ context: LoadingContext)
        throws (DesignLoaderError)
    {
        precondition(context.phase == .validated)
        let rawFrameIDs = context.rawFrames.map { $0.id }
        let rawSnapshotIDs = context.rawSnapshots.map { $0.snapshotID }
        let rawObjectIDs = context.rawSnapshots.map { $0.objectID }

        // Reservation Phase 1: Reserve those IDs we can
        if let failedIndex = reserveRequired(context, ids: rawSnapshotIDs, type: .objectSnapshot) {
            throw .snapshotError(failedIndex, .identityError(.duplicateID))
        }
        if let failedIndex = reserveRequired(context, ids: rawFrameIDs, type: .objectSnapshot) {
            throw .frameError(failedIndex, .identityError(.duplicateID))
        }
        if let failedIndex = reserveRequiredObjectIDs(context, ids: rawObjectIDs) {
            throw .frameError(failedIndex, .identityError(.duplicateID))
        }
    }

    /// Reserve IDs from the list of foreign IDs if possible.
    ///
    /// Only IDs that are convertible to ``EntityID/RawValue`` are considered, non-convertible
    /// are ignored.
    ///
    /// The reserved ID is stored in the context ID map (``LoadingContext/rawIDMap``)
    ///
    internal func reserveAvailable(_ context: LoadingContext,
                                   ids foreignIDs: some Collection<ForeignEntityID>,
                                   type: IdentityType)
    {
        precondition(context.phase == .validated)
        let identityManager = context.design.identityManager
        for foreignID in foreignIDs {
            guard let rawValue = foreignID.rawEntityIDValue else { continue }
            if identityManager.reserve(rawValue, type: type) {
                precondition(context.rawIDMap[foreignID] == nil) // Validation failed
                context.rawIDMap[foreignID] = rawValue
                context.reserved.append(rawValue)
            }
        }
    }

    internal func reserveAvailableObjectIDs(_ context: LoadingContext,
                                            ids foreignIDs: some Collection<ForeignEntityID>)
    {
        precondition(context.phase == .validated)
        let identityManager = context.design.identityManager
        for foreignID in foreignIDs {
            guard let rawValue = foreignID.rawEntityIDValue else { continue }
            guard !context.unavailableIDs.contains(rawValue) else { continue }
            
            if identityManager.reserveIfNeeded(ObjectID(rawValue: rawValue)) {
                precondition(context.rawIDMap[foreignID] == nil) // Validation failed
                context.rawIDMap[foreignID] = rawValue
                context.reserved.append(rawValue)
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
    internal func reserveRequired(_ context: LoadingContext,
                                  ids foreignIDs: some Collection<ForeignEntityID?>,
                                  type: IdentityType) -> Int?
    {
        precondition(context.phase == .validated)

        let identityManager = context.design.identityManager

        for (index, foreignID) in foreignIDs.enumerated() {
            guard let foreignID else { continue }
            precondition(context.rawIDMap[foreignID] == nil) // Validation failed

            guard let rawValue = foreignID.rawEntityIDValue else { continue }
            guard identityManager.reserve(rawValue, type: type) else {
                return index
            }
            context.rawIDMap[foreignID] = rawValue
            context.reserved.append(rawValue)
        }
        return nil
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
    internal func reserveRequiredObjectIDs(_ context: LoadingContext,
                                           ids foreignIDs: some Collection<ForeignEntityID?>) -> Int?
    {
        precondition(context.phase == .validated)

        let identityManager = context.design.identityManager

        for (index, foreignID) in foreignIDs.enumerated() {
            guard let foreignID else { continue }
            precondition(context.rawIDMap[foreignID] == nil) // Validation failed

            guard let rawValue = foreignID.rawEntityIDValue else { continue }
            guard !context.unavailableIDs.contains(rawValue),
                  identityManager.reserve(rawValue, type: .object) else {
                return index
            }
            context.rawIDMap[foreignID] = rawValue
            context.reserved.append(rawValue)
        }
        return nil
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
    internal func finaliseReservation<T>(_ context: LoadingContext,
                                     ids foreignIDs: some Collection<ForeignEntityID?>) -> [EntityID<T>]
    {
        precondition(context.phase == .validated)
        var result: [EntityID<T>] = []
        
        let identityManager = context.design.identityManager
        for foreignID in foreignIDs {
            let id: EntityID<T>
            if let foreignID {
                if let reservedID = context.rawIDMap[foreignID] {
                    assert(identityManager.type(reservedID) == T.identityType)
                    id = EntityID(rawValue: reservedID)
                }
                else {
                    id = identityManager.reserveNew()
                    context.rawIDMap[foreignID] = id.rawValue
                    context.reserved.append(id.rawValue)
                }
            }
            else {
                id = identityManager.reserveNew()
                context.reserved.append(id.rawValue)
            }
            result.append(id)
        }
        return result
    }

}
