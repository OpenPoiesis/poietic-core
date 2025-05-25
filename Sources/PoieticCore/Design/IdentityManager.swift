//
//  IdentityManager.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 05/05/2025.
//

public enum IdentityType: Sendable {
    /// Unique within design.
    case snapshot
    /// Unique within design.
    case frame
    /// Unique within frame, can be multiple within design. Used in references.
    case object
    // case track
}

/// Thread-safe identity management.
///
/// All methods are atomic. Intended to be used within transaction boundaries. Transactions
/// are responsible for reservations, consuming used or releasing unused reservations.
///
public class IdentityManager {
    @usableFromInline
    var sequence: UInt64 = 1
    @usableFromInline
    var used: [ObjectID:IdentityType] = [:]
    @usableFromInline
    var reserved: [ObjectID:IdentityType] = [:]
    
    @inlinable
    func contains(_ id: ObjectID) -> Bool {
        used[id] != nil || reserved[id] != nil
    }
    
    @inlinable
    func type(_ id: ObjectID) -> IdentityType? {
        used[id] ?? reserved[id]
    }
    @inlinable
    func next() -> ObjectID {
        var nextID = sequence
        var id = ObjectID(nextID)
        while contains(id) {
            nextID += 1
            id = ObjectID(nextID)
        }
        sequence = nextID + 1
        return id
    }
    
    /// Checks whether a given ID is reserved.
    ///
    /// - Returns: `true` when the ID is reserved, otherwise `false`. The method also returns `false`
    /// when the given ID is used, but not reserved.
    ///
    @inlinable
    public func isReserved(_ id: ObjectID) -> Bool {
        reserved[id] != nil
    }
    
    /// Checks whether a given ID is used.
    ///
    /// - Returns: `true` when the ID is used, otherwise `false`. The method also returns `false`
    /// when the given ID is reserved, but not used.
    ///
    @inlinable
    public func isUsed(_ id: ObjectID) -> Bool {
        used[id] != nil
    }
    
    @inlinable
    func createAndUse(type: IdentityType) -> ObjectID {
        let nextID = next()
        used[nextID] = type
        return nextID
    }
    
    @inlinable
    @discardableResult
    public func createAndReserve(type: IdentityType) -> ObjectID {
        let nextID = next()
        reserved[nextID] = type
        return nextID
    }
    
    @inlinable
    @discardableResult
    public func reserve(_ id: ObjectID, type: IdentityType) -> Bool {
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
    public func reserveIfNeeded(_ id: ObjectID, type requiredType: IdentityType) -> Bool {
        if let existingType = type(id) {
            return existingType == requiredType
        }
        else {
            reserved[id] = requiredType
            return true
        }
    }
    
    /// Returns: `true` if there was a reservation for given ID and was released. Otherwise returns
    ///          `false`.
    @inlinable
    @discardableResult
    public func freeReservation(_ id: ObjectID) -> Bool {
        reserved.removeValue(forKey: id) != nil
    }
    
    @inlinable
    public func freeReservations(_ toFree: [ObjectID]) {
        for id in toFree {
            reserved.removeValue(forKey: id)
        }
    }
    /// Use reservations from the list.
    ///
    /// The IDs in the list will be marked as used.
    ///
    /// - Precondition: All objects in the list must be reserved.
    ///
    @inlinable
    public func use(reserved ids: some Collection<ObjectID>) {
        for id in ids {
            guard let type = self.reserved.removeValue(forKey: id) else {
                fatalError("Unknown ID reservation: \(id)")
            }
            used[id] = type
        }
    }

    /// Use previously reserved ID.
    ///
    /// The ID will be marked as used.
    ///
    /// - Precondition: The ID must be reserved when calling this method.
    ///
    @inlinable
    public func use(reserved id: ObjectID) {
        guard let type = reserved.removeValue(forKey: id) else {
            fatalError("Unknown ID reservation: \(id)")
        }
        used[id] = type
    }
    
    @inlinable
    internal func use(new id: ObjectID, type: IdentityType) {
        precondition(!contains(id))
        used[id] = type
    }

    @inlinable
    public func free(_ id: ObjectID) {
        precondition(used[id] != nil)
        used[id] = nil
    }
}

public class RCIdentityManager {
    @usableFromInline
    struct RefCountCell {
        @usableFromInline
        let type: IdentityType
        
        @usableFromInline
        var refCount: Int
        
        @usableFromInline
        internal init(_ type: IdentityType, refCount: Int = 1) {
            self.type = type
            self.refCount = refCount
        }
    }
    
    @usableFromInline
    var sequence: UInt64 = 1
    @usableFromInline
    var used: [ObjectID:RefCountCell] = [:]
    @usableFromInline
    var reserved: [ObjectID:IdentityType] = [:]
    
    @inlinable
    func contains(_ id: ObjectID) -> Bool {
        used[id] != nil || reserved[id] != nil
    }
    
    @inlinable
    func type(_ id: ObjectID) -> IdentityType? {
        used[id].map { $0.type } ?? reserved[id]
    }
    @inlinable
    func next() -> ObjectID {
        var nextID = sequence
        var id = ObjectID(nextID)
        while contains(id) {
            nextID += 1
            id = ObjectID(nextID)
        }
        sequence = nextID + 1
        return id
    }
    
    /// Checks whether a given ID is reserved.
    ///
    /// - Returns: `true` when the ID is reserved, otherwise `false`. The method also returns `false`
    /// when the given ID is used, but not reserved.
    ///
    @inlinable
    public func isReserved(_ id: ObjectID) -> Bool {
        reserved[id] != nil
    }
    
    /// Checks whether a given ID is used.
    ///
    /// - Returns: `true` when the ID is used, otherwise `false`. The method also returns `false`
    /// when the given ID is reserved, but not used.
    ///
    @inlinable
    public func isUsed(_ id: ObjectID) -> Bool {
        used[id] != nil
    }
    
    @inlinable
    func createAndUse(type: IdentityType) -> ObjectID {
        let nextID = next()
        used[nextID] = RefCountCell(type)
        return nextID
    }
    
    @inlinable
    func retain(_ id: ObjectID) {
        precondition(used[id] != nil)
        used[id]!.refCount += 1
    }
    
    @inlinable
    func release(_ id: ObjectID) {
        precondition(used[id] != nil)
        precondition(used[id]!.refCount > 0)
        
        used[id]!.refCount -= 1
        if used[id]!.refCount <= 0 {
            used[id] = nil
        }
    }
    
    @inlinable
    func referenceCount(_ id: ObjectID) -> Int {
        guard let cell = used[id] else {
            preconditionFailure("Missing ID \(id)")
        }
        return cell.refCount
    }
    
    @inlinable
    @discardableResult
    public func createAndReserve(type: IdentityType) -> ObjectID {
        let nextID = next()
        reserved[nextID] = type
        return nextID
    }
    
    @inlinable
    @discardableResult
    public func reserve(_ id: ObjectID, type: IdentityType) -> Bool {
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
    public func reserveIfNeeded(_ id: ObjectID, type requiredType: IdentityType) -> Bool {
        if let existingType = type(id) {
            return existingType == requiredType
        }
        else {
            reserved[id] = requiredType
            return true
        }
    }
    
    /// Returns: `true` if there was a reservation for given ID and was released. Otherwise returns
    ///          `false`.
    @inlinable
    @discardableResult
    public func freeReservation(_ id: ObjectID) -> Bool {
        reserved.removeValue(forKey: id) != nil
    }
    
    @inlinable
    public func freeReservations(_ toFree: [ObjectID]) {
        for id in toFree {
            reserved.removeValue(forKey: id)
        }
    }
    @inlinable
    public func useReservations(_ toUse: [ObjectID]) {
        for id in toUse {
            if let type = reserved.removeValue(forKey: id) {
                used[id] = RefCountCell(type)
            }
        }
    }
    
    @inlinable
    @discardableResult
    public func use(_ id: ObjectID, type requiredType: IdentityType) -> Bool {
        guard used[id] == nil else { return false }
        if let type = reserved[id] {
            guard type == requiredType else { return false }
            reserved[id] = nil
        }
        used[id] = RefCountCell(requiredType)
        return true
    }
    
    @inlinable
    public func free(_ id: ObjectID) {
        precondition(used[id] != nil)
        used[id] = nil
    }
}

