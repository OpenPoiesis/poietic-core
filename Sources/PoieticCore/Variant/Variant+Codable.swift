//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 08/05/2024.
//

/*
 
 Variant -> JSONValue -> Data -> JSON String -> CSV
 Variant -> Data -> JSON text

 Encoding methods:
 
 - for persistent storage, type separate
 
 ["[int]", [1,2,3]]
 ai [1,2,3]
 
 ["int", 1234]
 i 1234
 
 
 ["string", "this is a string"]
 s "this is a string"
 
 */

// FIXME: [WIP] Add NaN and Inf for doubles + document it in JSONReader

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
    /// If the flag is `true`, then the decoder tries to decode an any type
    /// from the decoder and then tries to convert it to the closest convertable
    /// variant type.
    ///
    /// If the flag is `false` (default), the decoder expects a two-value
    /// array to be encoded where the first value is a variant
    /// type code (``ValueType/typeCode``) and the second value is encoded
    /// variant.
    ///
    static let CodingTypeKey: CodingUserInfoKey = CodingUserInfoKey(rawValue: "CodingTypeKey")!

    public enum CodingType: Sendable {
        /// Try to convert to/from native JSON value. Preserving the correct type is not guaranteed.
        case coalescing  // try to convert from value
        
        /// Encode as dictionary.
        ///
        /// - `{ "type": "int", "value": 10}`
        /// - `{ "type": "int_array", "items": [10, 20, 30]}`
        case dictionary
        /// Try reading as dictionary, if it fails, read coalescing value.
        ///
        /// Use this for reading only.
        ///
        /// When used for encoding, it is encoded as dictionary.
        ///
        case dictionaryWithFallback  // try dictionary, if it fails, use coalescing
        /// Legacy coding type as a tuple. Do not use.
        case tuple       // [type_name, value]
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case value
        case items
    }
    
    /// Read a variant from a decoder.
    ///
    /// For reading JSON that might be hand-written (more error-prone):
    ///
    /// ```swift
    /// let decoder = JSONDecoder()
    /// decoder.userInfo[Variant.CodingTypeKey] = .coalescing
    /// ```
    ///
    /// Reading a foreign frame produced by the library:
    ///
    /// ```swift
    /// let decoder = JSONDecoder()
    /// decoder.userInfo[Variant.CoalescedCodingTypeKey] = .dictionary
    /// ```
    ///
    /// See ``Variant/CodingTypeKey`` for more information.
    ///
    public init(from decoder: any Decoder) throws {
        let codingType = decoder.userInfo[Self.CodingTypeKey] as? CodingType
        switch codingType {
        case .none, .coalescing:
            try self.init(coalescingValueFrom: decoder)
        case .tuple:
            try self.init(asTupleFrom: decoder)
        case .dictionary:
            try self.init(asDictionaryFrom: decoder)
        case .dictionaryWithFallback:
            do {
                try self.init(asDictionaryFrom: decoder)
            }
            catch {
                try self.init(coalescingValueFrom: decoder)
            }
        }
    }
    
    init(coalescingValueFrom decoder: any Decoder) throws {
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
            let value = try container.decode([Bool].self, forKey: .items)
            self = .array(.bool(value))
        case "int_array":
            let value = try container.decode([Int].self, forKey: .items)
            self = .array(.int(value))
        case "string_array":
            let value = try container.decode([String].self, forKey: .items)
            self = .array(.string(value))
        case "double_array":
            let value = try container.decode([Double].self, forKey: .items)
            self = .array(.double(value))
        case "point_array":
            let value = try container.decode([[Double]].self, forKey: .items)
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
        let codingType = encoder.userInfo[Self.CodingTypeKey] as? CodingType
        
        switch codingType {
        case .none, .coalescing:
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
        case .tuple:
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
        case .dictionary, .dictionaryWithFallback:
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
                try container.encode(value, forKey: .items)
            case let .array(.int(value)):
                try container.encode(value, forKey: .items)
            case let .array(.double(value)):
                try container.encode(value, forKey: .items)
            case let .array(.string(value)):
                try container.encode(value, forKey: .items)
            case let .array(.point(values)):
                let points = values.map {
                    [$0.x, $0.y]
                }
                
                try container.encode(points, forKey: .items)
            }
        }
    }
}

extension JSONValue {
    /// Get a variant value with type represented within the JSON.
    ///
    /// Typed variant is represented as a dictionary
    var typedVariantValue: Variant? {
        guard let dict = self.objectValue,
              let type = dict["type"]?.stringValue
        else {
            return nil
        }
        
        switch type {
        case "bool":
            guard let value = dict["value"]?.boolValue else {
                return nil
            }
            return .atom(.bool(value))
        case "int":
            guard let value = dict["value"]?.intValue else {
                return nil
            }
            return .atom(.int(value))
        case "float":
            guard let value = dict["value"]?.doubleValue else {
                return nil
            }
            return .atom(.double(value))
        case "string":
            guard let value = dict["value"]?.stringValue else {
                return nil
            }
            return .atom(.string(value))
        case "point":
            guard let items = dict["value"]?.arrayValue,
                  items.count == 2,
                  let x = items[0].numericValue,
                  let y = items[1].numericValue
            else {
                return nil
            }
            return .atom(.point(Point(x, y)))
        case "bool_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Bool] = jsonItems.compactMap { $0.boolValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.bool(items))
        case "int_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Int] = jsonItems.compactMap { $0.intValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.int(items))
        case "float_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Double] = jsonItems.compactMap { $0.numericValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.double(items))
        case "string_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [String] = jsonItems.compactMap { $0.stringValue }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.string(items))
        case "point_array":
            guard let jsonItems = dict["items"]?.arrayValue else {
                return nil
            }
            let items: [Point] = jsonItems.compactMap {
                guard let items = $0.arrayValue,
                      items.count == 2,
                      let x = items[0].numericValue,
                      let y = items[1].numericValue
                else {
                    return nil
                }
                return Point(x, y)
            }
            guard items.count == jsonItems.count else {
                return nil
            }
            return .array(.point(items))
        default:
            return nil
        }
    }
    
    init(typedVariant variant: Variant) {
        switch variant {
        case .atom(let atom):
            let type: String
            let outValue: JSONValue
            switch atom {
            case .bool(let value):
                type = "bool"
                outValue = JSONValue.bool(value)
            case .int(let value):
                type = "int"
                outValue = JSONValue.int(value)
            case .double(let value):
                type = "float"
                outValue = JSONValue.float(value)
            case .string(let value):
                type = "string"
                outValue = JSONValue.string(value)
            case .point(let value):
                type = "point"
                outValue = JSONValue.array([.float(value.x), .float(value.y)])
            }
            self = .object([
                "type": .string(type),
                "value": outValue,
            ])
        case .array(let array):
            let type: String
            let outItems: [JSONValue]
            switch array {
            case .bool(let items):
                type = "bool"
                outItems = items.map { JSONValue.bool($0) }
            case .int(let items):
                type = "int"
                outItems = items.map { JSONValue.int($0) }
            case .double(let items):
                type = "float"
                outItems = items.map { JSONValue.float($0) }
            case .string(let items):
                type = "string"
                outItems = items.map { JSONValue.string($0) }
            case .point(let items):
                type = "point"
                outItems = items.map {
                    JSONValue.array([.float($0.x), .float($0.y)])
                }
            }
            self = .object([
                "type": .string(type),
                "items": .array(outItems),
            ])
        }
    }
}
