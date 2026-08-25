//
//  Variant+Codable.swift
//  poietic-core
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

    /// Code used for encoding of a variant value of the type.
    ///
    @available(*, deprecated, message: "Legacy, used in prototype/makeshift store")
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

    public var codingType: String {
        switch self {
        case let .atom(type):
            switch type {
            case .bool: "bool"
            case .int: "int"
            case .double: "float"
            case .string: "string"
            case .point: "point"
            }
        case let .array(type):
            switch type {
            case .bool: "bool_array"
            case .int: "int_array"
            case .double: "float_array"
            case .string: "string_array"
            case .point: "point_array"
            }
        }
    }

    @available(*, deprecated, message: "Legacy, used in prototype/makeshift store")
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
    @available(*, deprecated, message: "Legacy, used in prototype/makeshift store")
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.typeCode)
    }
}


extension Variant: Codable {
    /// Coding key used for a flag denoting how the variants are encoded.
    ///
    /// The value is of ``DecodingType`` type.
    ///
    /// - SeeAlso: ``Variant/init(jsonWithFallback:)``
    ///
    public static let DecodingTypeKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "DecodingTypeKey")!

    /// Specifier of the variant encoding method.
    ///
    /// - SeeAlso: ``Variant/init(jsonWithFallback:)``
    ///
    public enum DecodingType: Sendable {
        /// Decode as dictionary.
        ///
        /// - `{ "type": "int", "value": 10}`
        /// - `{ "type": "int_array", "items": [10, 20, 30]}`
        case dictionary
        
        /// Legacy coding type as a tuple. Do not use.
        case tuple       // [type_name, value]
        
        /// Decode as dictionary first, then try to guess from simple JSON value.
        ///
        /// Used in the tool for user input at command-line.
        ///
        /// - SeeAlso: ``Variant/init(jsonWithFallback:)``
        case dictionaryWithFallback
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case value
        // TODO: Deprecated. Remove once happy.
        case items
    }
    
    public init(from decoder: any Decoder) throws {
        let type = decoder.userInfo[Self.DecodingTypeKey] as? DecodingType
        switch type {
        case .none, .dictionary:
            try self.init(asDictionaryFrom: decoder)
        case .tuple:
            try self.init(asTupleFrom: decoder)
        case .dictionaryWithFallback:
            do {
                try self.init(asDictionaryFrom: decoder)
            }
            catch {
                try self.init(guessingValueFrom: decoder)
            }
        }
    }
    
    init(asTupleFrom decoder: any Decoder) throws {
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
    
    init(asDictionaryFrom decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        // Atoms
        case "bool":
            let value = try container.decode(Bool.self, forKey: .value)
            self = .atom(.bool(value))
        case "int":
            let value = try container.decode(Int.self, forKey: .value)
            self = .atom(.int(value))
        case "string":
            let value = try container.decode(String.self, forKey: .value)
            self = .atom(.string(value))
        case "float":
            let value = try container.decode(Double.self, forKey: .value)
            self = .atom(.double(value))
        case "point":
            let value = try container.decode([Double].self, forKey: .value)
            guard value.count == 2 else {
                throw VariantCodingError.invalidPointValue
            }
            let point = Point(value[0], value[1])
            self = .atom(.point(point))
            // Arrays
        case "bool_array":
            let value = try (try? container.decodeIfPresent([Bool].self, forKey: .items))
                         ?? (try container.decode([Bool].self, forKey: .value))
            self = .array(.bool(value))
        case "int_array":
            let value = try (try? container.decode([Int].self, forKey: .items))
                        ?? (try container.decode([Int].self, forKey: .value))
            self = .array(.int(value))
        case "string_array":
            let value = try (try? container.decode([String].self, forKey: .items))
                        ?? (try container.decode([String].self, forKey: .value))
            self = .array(.string(value))
        case "double_array":
            let value = try (try? container.decode([Double].self, forKey: .items))
                        ?? (try container.decode([Double].self, forKey: .value))
            self = .array(.double(value))
        case "point_array":
            let value = try (try? container.decode([[Double]].self, forKey: .items))
                        ?? (try container.decode([[Double]].self, forKey: .value))
            let points = try value.map { item in
                guard item.count == 2 else {
                    throw VariantCodingError.invalidPointValue
                }
                return Point(item[0], item[1])
            }
            self = .array(.point(points))
        default:
            throw VariantCodingError.invalidValueTypeCode(type)
        }

    }

    init(guessingValueFrom decoder: any Decoder) throws {
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
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(self.valueType.codingType, forKey: .type)
        switch self {
        case let .atom(.bool(value)):
            try container.encode(value, forKey: .value)
        case let .atom(.int(value)):
            try container.encode(value, forKey: .value)
        case let .atom(.double(value)):
            try container.encode(value, forKey: .value)
        case let .atom(.string(value)):
            try container.encode(value, forKey: .value)
        case let .atom(.point(value)):
            try container.encode([value.x, value.y], forKey: .value)
        case let .array(.bool(value)):
            try container.encode(value, forKey: .value)
        case let .array(.int(value)):
            try container.encode(value, forKey: .value)
        case let .array(.double(value)):
            try container.encode(value, forKey: .value)
        case let .array(.string(value)):
            try container.encode(value, forKey: .value)
        case let .array(.point(values)):
            let points = values.map {
                [$0.x, $0.y]
            }
            
            try container.encode(points, forKey: .value)
        }
    }
}
