//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/05/2024.
//

import Foundation

/// Error thrown when trying to decode a variant
///
/// - SeeAlso: ``ValueType/typeCode``
///
public enum VariantCodingError: Error {
    /// Type code not recognised.
    ///
    /// - SeeAlso: ``ValueType/typeCode``
    ///
    case invalidValueTypeCode(String)
    
    /// Point value is not encoded in expected form.
    ///
    case invalidPointValue
    
    /// Decoded variant value is of different type that the varian type
    /// code specifies.
    ///
    case invalidVariantValue
}

extension ValueType: Codable {

    /// Code used for encoding of a varian value of the type.
    ///
    public var typeCode: String {
        switch self {
        case let .atom(type):
            switch type {
            case .bool: "b"
            case .int: "i"
            case .double: "d"
            case .string: "s"
            case .point: "p"
            }
        case let .array(type):
            switch type {
            case .bool: "ab"
            case .int: "ai"
            case .double: "ad"
            case .string: "as"
            case .point: "ap"
            }
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(String.self)
        let type: ValueType = switch code {
        case "b": .atom(.bool)
        case "i": .atom(.int)
        case "d": .atom(.double)
        case "s": .atom(.string)
        case "p": .atom(.point)
        case "ab": .array(.bool)
        case "ai": .array(.int)
        case "ad": .array(.double)
        case "as": .array(.string)
        case "ap": .array(.point)
        default:
            throw VariantCodingError.invalidValueTypeCode(code)
        }
        
        self = type
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.typeCode)
    }
}


extension Variant: Codable {
    /// Coding key used for a flag denoting how the variants are encoded.
    ///
    /// If the flag is `true`, then the decoder tries to decode an any type
    /// from the decoder and then tries to convert it to the closest convertable
    /// variant type.
    ///
    /// If the flag is `false` (default), the decoder expects a two-value
    /// array to be encoded where the first value is a variant
    /// type code (``ValueType/typeCode``) and the second value is encoded
    /// variant.
    ///
    public static let CoalescedCodingTypeKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "CoalescedCodingTypeKey")!

    /// Read a variant from a decoder.
    ///
    /// For reading JSON that might be hand-written (more error-prone):
    ///
    /// ```swift
    /// let decoder = JSONDecoder()
    /// decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
    /// ```
    ///
    /// Reading a foreign frame produced by the library:
    ///
    /// ```swift
    /// let decoder = JSONDecoder()
    /// decoder.userInfo[Variant.CoalescedCodingTypeKey] = true
    /// ```
    ///
    /// See ``Variant/CoalescedCodingTypeKey`` for more information.
    ///
    public init(from decoder: any Decoder) throws {
        if decoder.userInfo[Self.CoalescedCodingTypeKey] as? Bool == true {
            let container = try decoder.singleValueContainer()
            
            if let value = try? container.decode(Int.self) {
                self = .atom(.int(value))
            }
            else if let value = try? container.decode(Double.self) {
                self = .atom(.double(value))
            }
            else if let value = try? container.decode(String.self) {
                self = .atom(.string(value))
            }
            else if let value = try? container.decode(Bool.self) {
                self = .atom(.bool(value))
            }
            else if let value = try? container.decode([Int].self) {
                self = .array(.int(value))
            }
            else if let value = try? container.decode([Double].self) {
                self = .array(.double(value))
            }
            else if let value = try? container.decode([String].self) {
                self = .array(.string(value))
            }
            else if let value = try? container.decode([Bool].self) {
                self = .array(.bool(value))
            }
            else if let items = try? container.decode([[Double]].self) {
                var points: [Point] = []
                for item in items {
                    guard item.count == 2 else {
                        throw VariantCodingError.invalidPointValue
                    }
                    let point = Point(x: item[0], y: item[1])
                    points.append(point)
                }
                self = .array(.point(points))
            }
            else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "Invalid variant value")
//                throw VariantCodingError.invalidVariantValue
            }
        }
        else {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(ValueType.self)
            switch type {
                // Atoms
            case .atom(.bool):
                let value = try container.decode(Bool.self)
                self = .atom(.bool(value))
            case .atom(.int):
                let value = try container.decode(Int.self)
                self = .atom(.int(value))
            case .atom(.string):
                let value = try container.decode(String.self)
                self = .atom(.string(value))
            case .atom(.double):
                let value = try container.decode(Double.self)
                self = .atom(.double(value))
            case .atom(.point):
                let value = try container.decode([Double].self)
                guard value.count == 2 else {
                    throw VariantCodingError.invalidPointValue
                }
                let point = Point(value[0], value[1])
                self = .atom(.point(point))
                // Arrays
            case .array(.bool):
                let value = try container.decode([Bool].self)
                self = .array(.bool(value))
            case .array(.int):
                let value = try container.decode([Int].self)
                self = .array(.int(value))
            case .array(.string):
                let value = try container.decode([String].self)
                self = .array(.string(value))
            case .array(.double):
                let value = try container.decode([Double].self)
                self = .array(.double(value))
            case .array(.point):
                let value = try container.decode([[Double]].self)
                let points = try value.map { item in
                    guard item.count == 2 else {
                        throw VariantCodingError.invalidPointValue
                    }
                    return Point(item[0], item[1])
                }
                self = .array(.point(points))
            }
        }
    }

    /// Encode the Variant into the encoder.
    ///
    /// There are two ways how the variant is encoded. One way stores the type
    /// explicitly in addition to the data, the other tries to convert the
    /// variant to one of the decoder's coding type.
    ///
    /// Default is encoding it as an array where the first element is the type
    /// and the second element is the variant content.
    ///
    /// The data type is encoded as one of the ``ValueType/typeCode`` values.
    ///
    /// Example: An integer value `10` would be encoded in JSON as `["i", 10]`
    /// by default. If coalesced encoding is requested then it will be encoded
    /// just as a number `10`.
    ///
    /// To enable coalescing, set the ``Variant/CoalescedCodingTypeKey`` to `true`:
    ///
    /// ```swift
    ///     let encoder = JSONEncoder()
    ///     encoder.userInfo[Variant.CoalescedCodingTypeKey] = true
    /// ```
    ///
    /// - SeeAlso: ``init(from:)``, ``ValueType/typeCode``, ``Variant/CoalescedCodingTypeKey``
    ///
    public func encode(to encoder: any Encoder) throws {
        if encoder.userInfo[Self.CoalescedCodingTypeKey] as? Bool == true {
            var container = encoder.singleValueContainer()
            switch self {
            case let .atom(.bool(value)):
                try container.encode(value)
            case let .atom(.int(value)):
                try container.encode(value)
            case let .atom(.double(value)):
                try container.encode(value)
            case let .atom(.string(value)):
                try container.encode(value)
            case let .atom(.point(value)):
                try container.encode([value.x, value.y])
            case let .array(.bool(value)):
                try container.encode(value)
            case let .array(.int(value)):
                try container.encode(value)
            case let .array(.double(value)):
                try container.encode(value)
            case let .array(.string(value)):
                try container.encode(value)
            case let .array(.point(values)):
                let points = values.map {
                    [$0.x, $0.y]
                }
                
                try container.encode(points)
            }
        }
        else {
            var container = encoder.unkeyedContainer()
            try container.encode(self.valueType.typeCode)
            switch self {
            case let .atom(.bool(value)):
                try container.encode(value)
            case let .atom(.int(value)):
                try container.encode(value)
            case let .atom(.double(value)):
                try container.encode(value)
            case let .atom(.string(value)):
                try container.encode(value)
            case let .atom(.point(value)):
                try container.encode([value.x, value.y])
            case let .array(.bool(value)):
                try container.encode(value)
            case let .array(.int(value)):
                try container.encode(value)
            case let .array(.double(value)):
                try container.encode(value)
            case let .array(.string(value)):
                try container.encode(value)
            case let .array(.point(values)):
                let points = values.map {
                    [$0.x, $0.y]
                }
                
                try container.encode(points)
            }
        }
    }
}

