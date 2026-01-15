//
//  IdentityManager.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 05/05/2025.
//

/// Thread-safe identity management.
///
/// All methods are atomic. Intended to be used within transaction boundaries. Transactions
/// are responsible for reservations, consuming used or releasing unused reservations.
///
public class IdentityManager {
    // IMPORTANT Development note: Keep this in sync with DesignEntityID
    
    @usableFromInline
    var sequence: UInt64 = 1
    @usableFromInline
    var used: [DesignEntityID:DesignEntityType] = [:]
    @usableFromInline
    var reserved: [DesignEntityID:DesignEntityType] = [:]
   
    /// Check whether the identity manager contains given ID regardless of its type.
    ///
    /// The identity manager contains the ID if it is either used or reserved.
    @inlinable
    func contains(_ id: DesignEntityID) -> Bool {
        used[id] != nil || reserved[id] != nil
    }

//    /// Check whether the identity manager contains given ID and wether the contained ID
//    /// is of the given type.
//    ///
//    /// The identity manager contains the ID if it is either used or reserved.
//    @inlinable
//    func contains<T>(_ id: EntityID<T>) -> Bool {
//        used[id.rawValue] == T.identityType || reserved[id.rawValue] == T.identityType
//    }
    
    @inlinable
    func type(_ id: DesignEntityID) -> DesignEntityType? {
        used[id] ?? reserved[id]
    }

    @inlinable
    internal func next() -> DesignEntityID {
        var nextValue = sequence
        while contains(DesignEntityID(intValue: nextValue)) {
            nextValue += 1
        }
        sequence = nextValue + 1
        return DesignEntityID(intValue: nextValue)
    }
    
    /// Checks whether a given ID is reserved.
    ///
    /// - Returns: `true` when the ID is reserved, otherwise `false`. The method also returns `false`
    /// when the given ID is used, but not reserved.
    ///
    @inlinable
    public func isReserved(_ id: DesignEntityID, type: DesignEntityType) -> Bool {
        reserved[id] == type
    }
    
    /// Checks whether a given ID is used.
    ///
    /// - Returns: `true` when the ID is used, otherwise `false`. The method also returns `false`
    /// when the given ID is reserved, but not used.
    ///
    @inlinable
    public func isUsed(_ id: DesignEntityID) -> Bool {
        used[id] != nil
    }
    
    @inlinable
    public func reserveNew(type: DesignEntityType) -> DesignEntityID {
        let nextID = next()
        reserved[nextID] = type
        return nextID
    }

    @inlinable
    @discardableResult
    public func reserve(_ id: DesignEntityID, type: DesignEntityType) -> Bool {
        if contains(id) {
            return false
        }
        else {
            reserved[id] = type
            return true
        }
    }
    
    /// - Returns: `true` when ID was successfully reserved or when ID already exists and is of the
    ///   requested type. If the ID exists and is of different type it returns `false`.
    @inlinable
    @discardableResult
    public func reserveIfNeeded(_ id: DesignEntityID, type: DesignEntityType) -> Bool {
        if let existingType = self.type(id) {
            return existingType == type
        }
        else { // we do not have the ID
            reserved[id] = type
            return true
        }
    }
    
    /// Returns: `true` if there was a reservation for given ID and was released. Otherwise returns
    ///          `false`.
    @inlinable
    @discardableResult
    public func freeReservation(_ id: DesignEntityID) -> Bool {
        reserved.removeValue(forKey: id) != nil
    }
    
    /// Free reservations regardless of their entity type.
    @inlinable
    public func freeReservations(_ toFree: [DesignEntityID]) {
        for id in toFree {
            reserved.removeValue(forKey: id)
        }
    }
    
    /// Use reservations from the list.
    ///
    /// The IDs in the list will be marked as used, if they are reserved.
    /// Not reserved IDs will be ignored.
    ///
    @inlinable
    public func use(reserved values: some Collection<DesignEntityID>) {
        // To be able to fail on non-reserved IDs, the reserveIfNeeded would have to distinguish
        // between: new reservation, existing reservation, type mismatch.
        for value in values {
            guard let type = self.reserved.removeValue(forKey: value) else {
                continue
            }
            used[value] = type
        }
    }

    /// Use previously reserved ID.
    ///
    /// The ID will be marked as used.
    ///
    /// - Precondition: The ID must be reserved when calling this method.
    ///
    @inlinable
    public func use(reserved id: DesignEntityID) {
        guard let type = reserved[id] else {
            fatalError("Unknown ID reservation: \(id)")
        }
        reserved[id] = nil
        used[id] = type
    }
    
    @inlinable
    internal func use(new id: DesignEntityID, type: DesignEntityType) {
        precondition(!contains(id))
        used[id] = type
    }

    @inlinable
    public func free(_ id: DesignEntityID) {
        precondition(used[id] != nil)
        used[id] = nil
    }
}

