//
//  IdentityManager.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 05/05/2025.
//

import Synchronization

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
    let ids: Mutex<Identities>
    
    init() {
        ids = Mutex(Identities())
    }

    @usableFromInline
    struct Identities: ~Copyable {
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
        mutating func next() -> ObjectID {
            var nextID = sequence
            var id = ObjectID(nextID)
            while contains(id) {
                nextID += 1
                id = ObjectID(nextID)
            }
            sequence = nextID + 1
            return id
        }
    }
    
    @inlinable
    public func contains(_ id: ObjectID) -> Bool {
        ids.withLock {
            $0.contains(id)
        }
    }

    @inlinable
    public func isReserved(_ id: ObjectID) -> Bool {
        ids.withLock {
            $0.reserved[id] != nil
        }
    }

    @inlinable
    public func isUsed(_ id: ObjectID) -> Bool {
        ids.withLock {
            $0.used[id] != nil
        }
    }

    @inlinable
    public func type(_ id: ObjectID) -> IdentityType? {
        ids.withLock {
            $0.type(id)
        }
    }

    @inlinable
    func createAndUse(type: IdentityType) -> ObjectID {
        ids.withLock {
            let nextID = $0.next()
            $0.used[nextID] = type
            return nextID
        }
    }
    @inlinable
    @discardableResult
    public func createAndReserve(type: IdentityType) -> ObjectID {
        ids.withLock {
            let nextID = $0.next()
            $0.reserved[nextID] = type
            return nextID
        }
    }
    
    @inlinable
    @discardableResult
    public func reserve(_ id: ObjectID, type: IdentityType) -> Bool {
        ids.withLock {
            if $0.contains(id) {
                return false
            }
            else {
                $0.reserved[id] = type
                return true
            }
        }
    }
    /// - Returns: `true` when ID was successfully reserved or when ID already exists and is of the
    ///   requested type. If the ID exists and is of different type it returns `false`.
    @inlinable
    @discardableResult
    public func reserveIfNeeded(_ id: ObjectID, type: IdentityType) -> Bool {
        ids.withLock {
            if let existingType = $0.type(id) {
                return existingType == type
            }
            else {
                $0.reserved[id] = type
                return true
            }
        }
    }

    /// Returns: `true` if there was a reservation for given ID and was released. Otherwise returns
    ///          `false`.
    @inlinable
    @discardableResult
    public func release(_ id: ObjectID) -> Bool {
        ids.withLock {
            $0.reserved.removeValue(forKey: id) != nil
        }
    }

    @inlinable
    public func releaseReservations(_ toRelease: [ObjectID]) {
        ids.withLock {
            for id in toRelease {
                $0.reserved.removeValue(forKey: id)
            }
        }
    }
    @inlinable
    public func useReservations(_ toUse: [ObjectID]) {
        ids.withLock {
            for id in toUse {
                if let type = $0.reserved.removeValue(forKey: id) {
                    $0.used[id] = type
                }
            }
        }
    }

    @inlinable
    @discardableResult
    public func use(_ id: ObjectID, type requiredType: IdentityType) -> Bool {
        ids.withLock {
            guard $0.used[id] == nil else { return false }
            if let type = $0.reserved[id] {
                guard type == requiredType else { return false }
                $0.reserved[id] = nil
            }
            $0.used[id] = requiredType
            return true
        }
    }
}

