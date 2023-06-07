//
//  UniqueIDGenerator.swift
//  
//
//  Created by Stefan Urbanek on 03/01/2022.
//


public typealias ID = UInt64

public typealias ObjectID = ID
public typealias SnapshotID = ID
public typealias FrameID = ID

/// Protocol for generators of unique object IDs.
///
public protocol IdentityGenerator {
    
    /// Returns a next unique object ID.
    func next() -> ObjectID
    
    /// Marks an ID to be already used. Prevents the generator from generating
    /// it. This is useful, for example, if the generator is providing IDs from
    /// a known pool of unique IDs, such as sequence of numbers.
    ///
    func markUsed(_ id: ObjectID)
}


/// Generator of IDs as a sequence of numbers starting from 1.
///
/// Subsequent sequential order continuity is not guaranteed.
///
/// - Note: This is very primitive and naive sequence number generator. If an ID
///   is marked as used and the number is higher than current sequence, all
///   numbers are just skipped and the next sequence would be the used +1.
///   
public class SequentialIDGenerator: IdentityGenerator {
    /// ID as a sequence number.
    var current: ObjectID
    
    /// Creates a sequential ID generator and initializes the sequence to 1.
    public init(_ initialValue: UInt64 = 1) {
        current = initialValue
    }
    
    /// Gets a next sequence id.
    public func next() -> ObjectID {
        let id = current
        current += 1
        return id
    }

    public func markUsed(_ id: ObjectID) {
        self.current = id + 1
    }
}
