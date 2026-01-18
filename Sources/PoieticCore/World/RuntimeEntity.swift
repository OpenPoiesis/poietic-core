//
//  EphemeralObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2025.
//

/// Ephemeral identity of a runtime entity.
///
/// Each entity in the ``World`` is represented by a runtime ID, which is valid only during the
/// lifetime of the World.
///
/// Design entities are given a runtime ID when presented in a world, for example through
/// ``World/setFrame(_:)``.
///
/// Runtime IDs are not persisted within the library and it is not recommended to store them.
///
///
/// - SeeAlso: ``DesignEntityID``, ``World/spawn(_:)``
///
/// - Note: The `RuntimeID` type is semantically equivalent to `EntityID` types in other
///   Entity-Component-System libraries. We are calling it `RuntimeID` to prevent naming
///   ambiguity with ``DesignEntityID``.
///   
public struct RuntimeID:
    Hashable,
    CustomStringConvertible,
    ExpressibleByIntegerLiteral,
    Sendable
{
    public typealias IntegerLiteralType = UInt64
    let value: UInt64
    
    public init(integerLiteral value: UInt64) {
        self.value = value
    }
    
    public init(intValue: UInt64) {
        self.value = intValue
    }

    public var asUInt64: UInt64 { self.value }
    
    public var description: String { String(value) }
}
