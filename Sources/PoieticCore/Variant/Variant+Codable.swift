//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/05/2024.
//

import Foundation

public enum VariantCodingError: Error {
    case invalidValueTypeCode(String)
    case invalidPointValue
}

extension ValueType: Codable {
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
    // Use default implementation.
    // NOTE: Do not use Codable for anything public (import/export).
    // NOTE: For JSON that is to be exported/imported use custom JSON methods.
    public init(from decoder: any Decoder) throws {
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
    public func encode(to encoder: any Encoder) throws {
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

