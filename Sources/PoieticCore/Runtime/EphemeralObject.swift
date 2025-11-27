//
//  EphemeralObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2025.
//

public struct EphemeralID:
    Hashable,
    RawRepresentable,
    CustomStringConvertible,
    ExpressibleByIntegerLiteral,
    Sendable
{
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
    
    public typealias IntegerLiteralType = UInt64
    
    public var rawValue: UInt64
    
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    public var description: String { String(rawValue) }
}

/// Unique identity used during runtime for storing components in ``AugmentedFrame``.
/// 
public enum RuntimeEntityID:
    Hashable,
    CustomStringConvertible,
    Sendable
{
    // Runtime entity backed by a design object
    case object(ObjectID)
    // Ephemeral runtime entity that is not backed by a concrete object.
    case ephemeral(EphemeralID)

    // ID of an ephemeral entity that represents the whole frame.
    public static let Frame = RuntimeEntityID.ephemeral(0)
    // NOTE: Update this constant based on the known list of reserved values
    internal static let FirstEphemeralIDValue: UInt64 = 10

    public var objectID: ObjectID? {
        switch self {
        case .object(let id): id
        case .ephemeral(_): nil
        }
    }
    
    public var description: String {
        switch self {
        case .object(let id): "\(id)"
        case .ephemeral(let id): "e\(id)"
        }
    }
}
