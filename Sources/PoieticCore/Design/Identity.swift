//
//  Identity.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 25/09/2025.
//

public enum DesignEntityType: Sendable, CustomStringConvertible {
    /// Unique within design.
    case objectSnapshot
    /// Unique within design.
    case frame
    /// Unique within frame, can be multiple within design. Used in references.
    case object
    // case track
    
    public var description: String {
        switch self {
        case .objectSnapshot: "objectSnapshot"
        case .frame: "frame"
        case .object: "object"
        }
    }
}

/// Persistent identity of Design entities.
///
/// The ID uniquely identifies all design entities such as objects, object snapshots, frames etc.
/// The identity is persisted with the design and is valid between runtime sessions.
///
/// When design entities are included in the ``World``, they are represented by ephemeral
/// ``RuntimeID``s which are valid only during the runtime.
///
/// - SeeAlso ``RuntimeID``, ``IdentityManager``, ``TransientFrame/create(_:objectID:snapshotID:structure:parent:children:attributes:)``.
///
public struct DesignEntityID:
    Hashable,
    Codable,
    Sendable,
    CustomStringConvertible
{
    public private(set) var rawValue: UInt64
    
    /// Create a new ID from an int.
    ///
    public init(intValue value: UInt64) {
        self.rawValue = value
    }

    /// Create a new ID from a string representation of an unsigned 64bit integer.
    public init?(_ string: String) {
        guard let value = UInt64(string) else { return nil }
        self.rawValue = value
    }
    
    public var stringValue: String { String(rawValue) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        self.rawValue = try container.decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { stringValue }
}

/// Identity of a design object.
///
/// Design object identity is unique within design snapshot. One design object might have multiple
/// objet snapshots.
///
public typealias ObjectID = DesignEntityID

/// Identity of a design object snapshot - a version of a design object.
///
/// Design object snapshot is unique within design and within a design snapshot.
///
public typealias FrameID = DesignEntityID

/// Identity of a design snapshot - version of a design.
///
/// Design snapshot ID is unique within design.
///
public typealias ObjectSnapshotID = DesignEntityID
