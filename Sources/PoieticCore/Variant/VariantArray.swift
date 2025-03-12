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
   
    /// Create an empty array of given type.
    public init(type: AtomType) {
        switch type {
        case .bool:   self = .bool([])
        case .int:    self = .int([])
        case .double: self = .double([])
        case .string: self = .string([])
        case .point:  self = .point([])
        }
    }
    
    /// Create a variant array from an array of supported types.
    public init?(any value: [Any]) {
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
        case (.int,    .atom(.point)):   items.count == 2
        case (.int,    .atom(_)):        false
            
            // Double to string or to itself
        case (.double, .array(.string)): true
        case (.double, .array(.bool)):   false
        case (.double, .array(.int)):    true
        case (.double, .array(.double)): true
        case (.double, .array(.point)):  false
        case (.double, .atom(.point)):   items.count == 2
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
            
        case (.point, .atom(_)): false
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
    
    /// Get a point value from an array of items.
    ///
    /// The array is convertible to a point if it has exactly two items and
    /// when both items are convertible to a double.
    ///
    public func pointValue() throws (ValueError) -> Point {
        switch self {
        case .double(let items):
            guard items.count == 2 else {
                throw ValueError.conversionFailed(.array(itemType), .point)
            }
            return Point(x: items[0], y: items[1])
        case .int(let items):
            guard items.count == 2 else {
                throw ValueError.conversionFailed(.array(itemType), .point)
            }
            return Point(x: Double(items[0]), y: Double(items[1]))
        default:
            throw ValueError.notConvertible(.array(itemType), .point)
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
            // TODO: Escape quotes inside?
            content = values.map { "\"\($0)\"" }.joined(separator: ", ")
        case .bool(let values):
            content = values.map { String($0) }.joined(separator: ", ")
        case .point(let values):
            content = values.map { "[\($0.x), \($0.y)]" }.joined(separator: ", ")
        }
        
        return "[\(content)]"
    }
}

extension VariantArray: MutableCollection /* random access collection-like */ {
    public typealias Element = Variant
    public typealias Index = Array<Variant>.Index
    
    public var endIndex: Index { count }
    public var startIndex: Index { 0 }
    
    public subscript(position: Array<Variant>.Index) -> Variant {
        get {
            switch self {
            case .int(let values):
                Variant(values[position])
            case .double(let values):
                Variant(values[position])
            case .bool(let values):
                Variant(values[position])
            case .string(let values):
                Variant(values[position])
            case .point(let values):
                Variant(values[position])
            }
        }
        set(item) {
            switch (self, item) {
            case (var .int(items), let .atom(.int(item))):
                items[position] = item
                self = .int(items)
            case (var .bool(items), let .atom(.bool(item))):
                items[position] = item
                self = .bool(items)
            case (var .double(items), let .atom(.double(item))):
                items[position] = item
                self = .double(items)
            case (var .string(items), let .atom(.string(item))):
                items[position] = item
                self = .string(items)
            case (var .point(items), let .atom(.point(item))):
                items[position] = item
                self = .point(items)
            default:
                fatalError("Array and atom type mismatch")
            }
        }
    }

    public func index(after index: Index) -> Index {
        return index + 1
    }
    
    public mutating func append(_ item: VariantAtom) throws (ValueError) {
        switch (self, item) {
        case let (.int(items), .int(item)):
            self = VariantArray.int(items + [item])
        case let (.string(items), .string(item)):
            self = VariantArray.string(items + [item])
        case let (.double(items), .double(item)):
            self = VariantArray.double(items + [item])
        case let (.bool(items), .bool(item)):
            self = VariantArray.bool(items + [item])
        case let (.point(items), .point(item)):
            self = VariantArray.point(items + [item])
        // FIXME: [IMPORTANT] I've reached a point of realising that this needs some reconsidering
        case let (.int(items), atom):
            self = VariantArray.int(items + [try atom.intValue()])
        case let (.string(items), atom):
            self = VariantArray.string(items + [atom.stringValue()])
        case let (.double(items), atom):
            self = VariantArray.double(items + [try atom.doubleValue()])
        case let (.bool(items), atom):
            self = VariantArray.bool(items + [try atom.boolValue()])
        case let (.point(items), atom):
            self = VariantArray.point(items + [try atom.pointValue()])
        }
    }

    public mutating func remove(at index: Int) -> VariantAtom {
        switch self {
        case .int(var values):
            let result = values.remove(at: index)
            self = .int(values)
            return .int(result)
        case .double(var values):
            let result = values.remove(at: index)
            self = .double(values)
            return .double(result)
        case .bool(var values):
            let result = values.remove(at: index)
            self = .bool(values)
            return .bool(result)
        case .string(var values):
            let result = values.remove(at: index)
            self = .string(values)
            return .string(result)
        case .point(var values):
            let result = values.remove(at: index)
            self = .point(values)
            return .point(result)
        }
    }
    
    public var last: Variant? {
        if count == 0 {
            return nil
        }
        else {
            return self[count-1]
        }
    }
    public var first: Variant? {
        if count == 0 {
            return nil
        }
        else {
            return self[0]
        }
    }
}

extension VariantArray: Codable {
    // Use default implementation.
    // NOTE: Do not use Codable for anything public (import/export).
    // NOTE: For JSON that is to be exported/imported use custom JSON methods.
}

