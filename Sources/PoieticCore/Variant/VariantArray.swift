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

    /// Check whether the array value is convertible to a given value type.
    ///
    /// See ``Variant/isConvertible(to:)`` for more information.
    ///
    public func isConvertible(to type: ValueType) -> Bool {
        switch (self, type) {
        // Bool to string, int or itself only
        case (.bool,   .array(.string)): true
        case (.bool,   .array(.bool)):   true
        case (.bool,   .array(.int)):    true
        case (.bool,   .array(.double)): false
        case (.bool,   .array(.point)):  false
        case (.bool,   .atom(_)):      false
            
        // Int to all except point
        case (.int,    .array(.string)): true
        case (.int,    .array(.bool)):   true
        case (.int,    .array(.int)):    true
        case (.int,    .array(.double)): true
        case (.int,    .array(.point)):  false
        case (.int,    .atom(.point)):    items.count == 2
        case (.int,    .atom(_)):        false
            
        // Double to string or to itself
        case (.double, .array(.string)): true
        case (.double, .array(.bool)):   false
        case (.double, .array(.int)):    true
        case (.double, .array(.double)): true
        case (.double, .array(.point)):  false
        case (.double, .atom(.point)):    items.count == 2
        case (.double, .atom(_)):        false
            
        // String to all except point
        case (.string, .array(.string)): true
        case (.string, .array(.bool)):   true
        case (.string, .array(.int)):    true
        case (.string, .array(.double)): true
        case (.string, .array(.point)):  false
        case (.string, .atom(_)):        false
            
        // Point
        case (.point, .array(.string)): true
        case (.point, .array(.bool)):   false
        case (.point, .array(.int)):    false
        case (.point, .array(.double)): false
        case (.point, .array(.point)):  true
            
        case (.point, .atom(.string)): false
        case (.point, .atom(.bool)):   false
        case (.point, .atom(.int)):    true
        case (.point, .atom(.double)): true
        case (.point, .atom(.point)):  false
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
