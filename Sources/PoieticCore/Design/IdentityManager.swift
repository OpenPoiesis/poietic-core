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
    @usableFromInline
    var sequence: EntityID.RawValue = 1
    @usableFromInline
    var used: [EntityID.RawValue:IdentityType] = [:]
    @usableFromInline
    var reserved: [EntityID.RawValue:IdentityType] = [:]
   
    /// Check whether the identity manager contains given ID regardless of its type.
    ///
    /// The identity manager contains the ID if it is either used or reserved.
    @inlinable
    func contains(_ id: EntityID.RawValue) -> Bool {
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
    func type(_ rawID: EntityID.RawValue) -> IdentityType? {
        used[rawID] ?? reserved[rawID]
    }

    @inlinable
    internal func next() -> EntityID.RawValue {
        var nextValue = sequence
        while contains(nextValue) {
            nextValue += 1
        }
        sequence = nextValue + 1
        return nextValue
    }
    
    /// Checks whether a given ID is reserved.
    ///
    /// - Returns: `true` when the ID is reserved, otherwise `false`. The method also returns `false`
    /// when the given ID is used, but not reserved.
    ///
    @inlinable
    public func isReserved<T>(_ id: EntityID<T>) -> Bool {
        reserved[id.rawValue] == T.identityType
    }
    
    /// Checks whether a given ID is used.
    ///
    /// - Returns: `true` when the ID is used, otherwise `false`. The method also returns `false`
    /// when the given ID is reserved, but not used.
    ///
    @inlinable
    public func isUsed<T>(_ id: EntityID<T>) -> Bool {
        used[id.rawValue] != nil
    }
    
    // TODO: Remove this
    @inlinable
    func createAndUse<T>() -> EntityID<T> {
        let nextID = next()
        used[nextID] = T.identityType
        return EntityID(rawValue: nextID)
    }
    
    @inlinable
    public func reserveNew<T>() -> EntityID<T> {
        let nextID = next()
        reserved[nextID] = T.identityType
        return EntityID(rawValue: nextID)
    }
    @inlinable
    public func reserveNew(type: IdentityType) -> EntityID.RawValue {
        let nextID = next()
        reserved[nextID] = type
        return nextID
    }

    @inlinable
    @discardableResult
    public func reserve(_ rawValue: EntityID.RawValue, type: IdentityType) -> Bool {
        if contains(rawValue) {
            return false
        }
        else {
            reserved[rawValue] = type
            return true
        }
    }
    
    @inlinable
    @discardableResult
    public func reserve<T>(_ id: EntityID<T>) -> Bool {
        if contains(id.rawValue) {
            return false
        }
        else {
            reserved[id.rawValue] = T.identityType
            return true
        }
    }
    /// - Returns: `true` when ID was successfully reserved or when ID already exists and is of the
    ///   requested type. If the ID exists and is of different type it returns `false`.
    @inlinable
    @discardableResult
    public func reserveIfNeeded<T>(_ id: EntityID<T>) -> Bool {
        if let type = self.type(id.rawValue) {
            if type == T.identityType {
                return true
            }
            else {
                return false // We have the ID but is of different type
            }
        }
        else { // we do not have the ID
            reserved[id.rawValue] = T.identityType
            return true
        }
    }
    
    /// Returns: `true` if there was a reservation for given ID and was released. Otherwise returns
    ///          `false`.
    @inlinable
    @discardableResult
    public func freeReservation<T>(_ id: EntityID<T>) -> Bool {
        reserved.removeValue(forKey: id.rawValue) != nil
    }
    
    @inlinable
    public func freeReservations<T>(_ toFree: [EntityID<T>]) {
        for id in toFree {
            reserved.removeValue(forKey: id.rawValue)
        }
    }
    
    /// Free reservations regardless of their entity type.
    @inlinable
    public func freeReservations(_ values: [EntityID.RawValue]) {
        for value in values {
            reserved.removeValue(forKey: value)
        }
    }
    /// Use reservations from the list.
    ///
    /// The IDs in the list will be marked as used, if they are reserved.
    /// Not reserved IDs will be ignored.
    ///
    @inlinable
    public func use(reserved values: some Collection<EntityID.RawValue>) {
        // TODO: Rename to something that reflects the functionality more. For example: useIfReserved()
        // To be able to fail on non-reserved IDs, the reserveIfNeeded would have to distinguish
        // between: new reservation, existing reservation, type mismatch.
        for value in values {
            guard let type = self.reserved.removeValue(forKey: value) else {
                return
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
    public func use<T>(reserved id: EntityID<T>) {
        guard reserved.removeValue(forKey: id.rawValue) != nil else {
            fatalError("Unknown ID reservation: \(id)")
        }
        used[id.rawValue] = T.identityType
    }
    
    @inlinable
    internal func use<T>(new id: EntityID<T>) {
        precondition(!contains(id.rawValue))
        used[id.rawValue] = T.identityType
    }

    @inlinable
    public func free<T>(_ id: EntityID<T>) {
        precondition(used[id.rawValue] != nil)
        used[id.rawValue] = nil
    }
}

