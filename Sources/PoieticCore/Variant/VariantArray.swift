//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/03/2024.
//

public enum VariantArray: Equatable, CustomStringConvertible, Hashable, Sendable {

    /// Representation of an integer.
    case int([Int])
    
    /// Representation of a double precision floating point value.
    case double([Double])
    
    /// Representation of a text string.
    case string([String])
    
    /// Representation of a boolean value.
    case bool([Bool])
    
    /// Representation of a 2D point value.
    case point([Point])
   
    public init(_ values: [Int]) {
        self = .int(values)
    }
    public init(_ values: [Double]) {
        self = .double(values)
    }
    public init(_ values: [Bool]) {
        self = .bool(values)
    }
    public init(_ values: [Point]) {
        self = .point(values)
    }
    public init(_ values: [String]) {
        self = .string(values)
    }

    /// Create a variant array from an array of supported types.
    public init?<T>(any value: [T]) {
        switch value {
        case let value as [Int]: self = .int(value)
        case let value as [Double]: self = .double(value)
        case let value as [Bool]: self = .bool(value)
        case let value as [String]: self = .string(value)
        case let value as [Point]: self = .point(value)
        default: return nil
        }
    }
    
    /// Type of array's items.
    ///
    public var itemType: AtomType {
        switch self {
        case .int: .int
        case .double: .double
        case .string: .string
        case .bool: .bool
        case .point: .point
        }
    }
    
    
    public var count: Int {
        switch self {
        case .int(let values):
            values.count
        case .double(let values):
            values.count
        case .string(let values):
            values.count
        case .bool(let values):
            values.count
        case .point(let values):
            values.count
        }
    }

    public var items: [VariantAtom] {
        switch self {
        case .int(let values):
            values.map { .int($0) }
        case .double(let values):
            values.map { .double($0) }
        case .string(let values):
            values.map { .string($0) }
        case .bool(let values):
            values.map { .bool($0) }
        case .point(let values):
            values.map { .point($0) }
        }
    }
    public var stringItems: [String] {
        switch self {
        case .int(let values):
            values.map { String($0) }
        case .double(let values):
            values.map { String($0) }
        case .string(let values):
            values.map { String($0) }
        case .bool(let values):
            values.map { String($0) }
        case .point(let values):
            values.map { String(describing: $0) }
        }
    }

    
    public var description: String {
        let content: String
        
        switch self {
        case .int(let values):
            content = values.map { String($0) }.joined(separator: ", ")
        case .double(let values):
            content = values.map { String($0) }.joined(separator: ", ")
        case .string(let values):
            // TODO: Escape quotes inside
            content = values.map { "\"\($0)\"" }.joined(separator: ", ")
        case .bool(let values):
            content = values.map { String($0) }.joined(separator: ", ")
        case .point(let values):
            content = values.map { String(describing: $0) }.joined(separator: ", ")
        }
        
        return "[\(content)]"
    }
}

extension VariantArray: Codable {
    // Use default implementation.
    // NOTE: Do not use Codable for anything public (import/export).
    // NOTE: For JSON that is to be exported/imported use custom JSON methods.
}
