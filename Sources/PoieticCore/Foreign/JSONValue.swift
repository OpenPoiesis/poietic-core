//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/03/2024.
//

import Foundation

public enum JSONType: Equatable, Sendable {
    case int
    case double
    case string
    case bool
    case array
    case object
    case null
}

public enum JSONValue: Equatable, Codable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case array([JSONValue])
    case object([String:JSONValue])
    case null

    public var type: JSONType {
        switch self {
        case .int: .int
        case .double: .double
        case .string: .string
        case .bool: .bool
        case .array: .array
        case .object: .object
        case .null: .null
        }
    }
   
    public init(string: String) throws {
        let data = Data(string.utf8)
        try self.init(data: data)
    }
    
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        do {
            self = try decoder.decode(JSONValue.self, from: data)
        }
        catch DecodingError.dataCorrupted {
            throw JSONError.dataCorrupted
        }
        catch {
            fatalError("Unhandled JSON decoding error: \(error). Hint: Broken JSONValue decoding")
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        }
        else if let value = try? container.decode(Int.self) {
            self = .int(value)
        }
        else if let value = try? container.decode(Double.self) {
            self = .double(value)
        }
        else if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        }
        else if let items = try? container.decode([String:JSONValue].self) {
            self = .object(items)
        }
        else {
            let _: Int? = try container.decode((Int?).self)
            // This must be null, since we tried Int above
            self = .null
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .int(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(array):
            try container.encode(array)
        case let .object(dict):
            try container.encode(dict)
        case .null:
            try container.encode(Int?(nil))
        }
    }
    
    public func asJSONString() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let string = String(data: data, encoding: .utf8)!
        return string
    }

    /// Return a Foundation compatible JSON object structure.
    ///
    public func asAnyValue() -> Any? {
        switch self {
        case let .int(value):
            return value
        case let .bool(value):
            return value
        case let .double(value):
            return value
        case let .string(value):
            return value
        case let .array(array):
            return array.map { $0.asAnyValue() }
        case let .object(dict):
            let itemsAsAny = dict.map { ($0.key, $0.value.asAnyValue()) }
            return Dictionary(uniqueKeysWithValues: itemsAsAny)
        case .null:
            return nil
        }
    }

    public func asDictionary() -> [String:JSONValue]? {
        switch self {
        case let.object(dict):
            return dict
        default:
            return nil
        }
    }
    
    public func asArray() -> Array<JSONValue>? {
        switch self {
        case let.array(items):
            return items
        default:
            return nil
        }
    }

    @inlinable
    public func asString() throws -> String {
        if case let .string(value) = self {
            return value
        }
        else {
            throw JSONError.typeMismatch(.string, nil)
        }
    }
    
    @inlinable
    public func asInt() throws -> Int {
        if case let .int(value) = self {
            return value
        }
        else {
            throw JSONError.typeMismatch(.string, nil)
        }
    }

    @inlinable
    public func asBool() throws -> Bool {
        if case let .bool(value) = self {
            return value
        }
        else {
            throw JSONError.typeMismatch(.string, nil)
        }
    }

    @inlinable
    public func asDouble() throws -> Double {
        if case let .double(value) = self {
            return value
        }
        else {
            throw JSONError.typeMismatch(.string, nil)
        }
    }

}

public typealias JSONDictionary = [String:JSONValue]

extension JSONDictionary {
    @inlinable
    public func valueIfPresent(forKey key: String ) throws -> JSONValue? {
        self[key]
    }
    
    @inlinable
    public func value(forKey key: String ) throws -> JSONValue {
        if let value = self[key] {
            value
        }
        else {
            throw JSONError.propertyNotFound(key)
        }
    }

    public func stringIfPresent(forKey key: String ) throws -> String? {
        guard let jsonValue = self[key] else {
            return nil
        }
        if case let .string(value) = jsonValue {
            return value
        }
        else {
            throw JSONError.typeMismatch(.string, key)
        }
    }
    
    public func string(forKey key: String ) throws -> String {
        if let value = try stringIfPresent(forKey: key) {
            value
        }
        else {
            throw JSONError.propertyNotFound(key)
        }
    }

    public func boolIfPresent(forKey key: String) throws -> Bool? {
        guard let jsonValue = self[key] else {
            return nil
        }
        if case let .bool(value) = jsonValue {
            return value
        }
        else {
            throw JSONError.typeMismatch(.bool, key)
        }
    }
    public func bool(forKey key: String ) throws -> Bool {
        if let value = try boolIfPresent(forKey: key) {
            value
        }
        else {
            throw JSONError.propertyNotFound(key)
        }
    }

    public func intIfPresent(forKey key: String) throws -> Int? {
        guard let jsonValue = self[key] else {
            return nil
        }
        if case let .int(value) = jsonValue {
            return value
        }
        else {
            throw JSONError.typeMismatch(.int, key)
        }
    }
    public func int(forKey key: String ) throws -> Int {
        if let value = try intIfPresent(forKey: key) {
            value
        }
        else {
            throw JSONError.propertyNotFound(key)
        }
    }
    public func doubleIfPresent(forKey key: String) throws -> Double? {
        guard let jsonValue = self[key] else {
            return nil
        }
        if case let .double(value) = jsonValue {
            return value
        }
        else {
            throw JSONError.typeMismatch(.double, key)
        }
    }
    public func double(forKey key: String ) throws -> Double {
        if let value = try doubleIfPresent(forKey: key) {
            value
        }
        else {
            throw JSONError.propertyNotFound(key)
        }
    }
    
    public func arrayIfPresent(forKey key: String) throws -> [JSONValue]? {
        guard let jsonValue = self[key] else {
            return nil
        }
        if case let .array(value) = jsonValue {
            return value
        }
        else {
            throw JSONError.typeMismatch(.array, key)
        }
    }
    public func array(forKey key: String ) throws -> [JSONValue] {
        if let value = try arrayIfPresent(forKey: key) {
            value
        }
        else {
            throw JSONError.propertyNotFound(key)
        }
    }
}

public enum JSONError: Error, Equatable, CustomStringConvertible {
    case dataCorrupted
    case propertyNotFound(String)
    case typeMismatch(JSONType, String?)

    public var description: String {
        switch self {
        case .dataCorrupted:
            return "Data corrupted or format malformed."
        case .propertyNotFound(let name):
            return "Missing property '\(name)'"
        case .typeMismatch(let expected, let key):
            let context: String
            if let key {
                context = " for key '\(key)'"
            }
            else {
                context = ""
            }
            return "Type mismatch\(context). Expected: \(expected).."
        }
    }
}
