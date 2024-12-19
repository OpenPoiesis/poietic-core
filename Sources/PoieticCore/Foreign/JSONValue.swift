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

/// Representation of a JSON value.
///
/// The enum represents a JSON value, array or an object.
///
/// Main use of the JSON value is to have finer control over encoding and decoding of ``Variant``
/// using JSON.
///
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
   
    public init(parsing string: String) throws (JSONError) {
        let data = Data(string.utf8)
        try self.init(data: data)
    }
    
    public init(data: Data) throws (JSONError) {
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
    
    public func asJSONString() -> String {
        // This method must not fail. If it fails, there must be a bug somewhere. Errors are ours
        // not user's.
        
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(self)
        }
        catch {
            fatalError("JSONValue encoding failed")
        }
        guard let string = String(data: data, encoding: .utf8) else {
            fatalError("JSONValue string conversion failed")
        }
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

    /// Get integer value of a numeric JSON value.
    ///
    /// - Returns: Int if the JSON value is an int or an int-convertible double.
    ///   Otherwise `nil`.
    ///
    @inlinable
    public func exactInt() -> Int? {
        switch self {
        case .int(let value): return value
        case .double(let value):
            if let converted = Int(exactly: value) {
                return converted
            }
            else {
                return nil
            }
        default:
            return nil
        }
    }

    /// Get double value of a numeric JSON value.
    ///
    /// - Returns: Int if the JSON value is a double or a double-convertible double.
    ///   Otherwise `nil`.
    ///
    @inlinable
    public func exactDouble() -> Double? {
        switch self {
        case .double(let value): return value
        case .int(let value):
            if let converted = Double(exactly: value) {
                return converted
            }
            else {
                return nil
            }
        default:
            return nil
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

