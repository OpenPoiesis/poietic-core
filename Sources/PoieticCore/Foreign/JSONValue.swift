//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/03/2024.
//

import Foundation

public enum JSONType: Equatable {
    case int
    case double
    case string
    case bool
    case array
    case object
    case null
}

public enum JSONValue: Equatable, Decodable, Encodable {
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
        let decoder = JSONDecoder()
        self = try decoder.decode(JSONValue.self, from: data)
    }
    
    public init(from decoder: Decoder) throws {
        // TODO: Use option for single value
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        else if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        else if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        else if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        else if let items = try? container.decode([String:JSONValue].self) {
            self = .object(items)
            return
        }
        else {
            let _: Int? = try container.decode((Int?).self)
            // This must be null, since we tried Int above
            self = .null
            return
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .int(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(array):
            var container = encoder.singleValueContainer()
            try container.encode(array)
        case let .object(dict):
            var container = encoder.singleValueContainer()
            try container.encode(dict)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encode(Int?(nil))
        }
    }
    
    public func asJSONString() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let string = String(data: data, encoding: .utf8)!
        return string
    }
}

