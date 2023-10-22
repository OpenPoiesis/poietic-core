//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import Foundation

extension ForeignAtom {
    public static func fromJSON(_ string: String) throws -> ForeignAtom {
        let data = Data(string.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(ForeignAtom.self, from: data)
    }
    
    /// Create a Foundation-compatible JSON object representation.
    ///
    public func asJSONObject() -> Any {
        switch self {
        case let .int(value):  value
        case let .double(value): value
        case let .string(value): value
        case let .bool(value): value
        case let .id(value): value
        case let .point(value): [value.x, value.y]
        }
    }
}

extension ForeignValue {
    public static func fromJSON(_ string: String) throws -> ForeignValue {
        let data = Data(string.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(ForeignValue.self, from: data)
    }
    
    /// Create a Foundation-compatible JSON object representation.
    ///
    public func asJSONObject() -> Any {
        switch self {
        case .atom(let value): value.asJSONObject()
        case .array(let items): items.map { $0.asJSONObject() }
        }
    }
}

extension ForeignRecord {
    /// Create a Foundation-compatible JSON object representation.
    ///
    public func asJSONObject() -> Any {
        dict.mapValues { $0.asJSONObject() }
    }
}
