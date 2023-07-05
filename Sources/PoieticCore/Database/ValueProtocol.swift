//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 2020/12/14.
//

// FIXME: Values are a mess, we have Value, ValueProtocol and ForeignValue - needs to be merged together


// TODO: Use ValueProtocol and then Something.asValue
// TODO: IMPORTANT: Read the following note.
// IMPORTANT NOTE:
//
// The value protocol has been designed originally to serve two purposes:
// - internal representation of a value
// - foreign value – value imported/exported
//
// The internal value should be represented as enum.
// The foreign value has been separated, making this protocol irrelevant in its
// original form.
// 

public typealias Point = SIMD2<Double>

/// Protocol for objects that can be represented as ``Value``.
///
public protocol ValueProtocol: Hashable, Codable {
    /// Representation of the receiver as a ``Value``
    /// 
//    func asValue() -> Value
    var valueType: ValueType { get }
    
    /// Return bool equivalent of the object, if possible.
    func boolValue() -> Bool?

    /// Return integer equivalent of the object, if possible.
    func intValue() -> Int?

    /// Return double floating point equivalent of the object, if possible.
    func doubleValue() -> Double?

    /// Return string equivalent of the object, if possible.
    func stringValue() -> String?

    /// Return string equivalent of the object, if possible.
    func pointValue() -> Point?

    // FIXME: Replace this with Equatable
    /// Tests whether two values are equal.
    ///
    /// Two objects conforming to value protocol are equal if they
    /// are of the same type and if their values are equal.
    ///
    func isEqual(to other: any ValueProtocol) -> Bool
    //    func convert(to otherType: ValueType) -> Value?
}

extension ValueProtocol {
    public func pointValue() -> Point? { nil }
}

extension ValueProtocol {
    public func isEqual(to other: any ValueProtocol) -> Bool {
        guard self.valueType == other.valueType else {
            return false
        }
        switch self.valueType {
        case .bool: return self.boolValue() == other.boolValue()
        case .int: return self.intValue() == other.intValue()
        case .double: return self.doubleValue() == other.doubleValue()
        case .string: return self.stringValue() == other.stringValue()
        case .point: return self.pointValue() == other.pointValue()
        }
    }
}

/// ValueType specifies a data type of a value that is used in interfaces.
///
public enum ValueType: String, Equatable, Codable, CustomStringConvertible {
    case bool = "bool"
    case int = "int"
    case double = "double"
    case string = "string"
    case point = "point"
    // case id
    // case date
    
    /// Returns `true` if the value of this type is convertible to
    /// another type.
    /// Conversion might not be precise, just possible.
    ///
    public func isConvertible(to other: ValueType) -> Bool{
        switch (self, other) {
        // Bool to string, not to int or float
        case (.bool,   .string): return true
        case (.bool,   .bool):   return true
        case (.bool,   .int):    return false
        case (.bool,   .double): return false
        case (.bool,   .point):    return false

        // Int to all except bool
        case (.int,    .string): return true
        case (.int,    .bool):   return false
        case (.int,    .int):    return true
        case (.int,    .double): return true
        case (.int, .point):     return false

        // Float to all except bool
        case (.double, .string): return true
        case (.double, .bool):   return false
        case (.double, .int):    return true
        case (.double, .double): return true
        case (.double, .point):  return false

        // String to all
        case (.string, .string): return true
        case (.string, .bool):   return true
        case (.string, .int):    return true
        case (.string, .double): return true
        case (.string, .point):  return false

        // Point to point or a string
        case (.point, .string): return false
        case (.point, .bool):   return false
        case (.point, .int):    return false
        case (.point, .double): return false
        case (.point, .point):  return true

        }
    }
    
    public var description: String {
        self.rawValue
    }
    /// True if the type is either `int` or `float`
    public var isNumeric: Bool {
        switch self {
        case .double: return true
        case .int: return true
        default: return false
        }
    }    
}

extension String: ValueProtocol {
    public var valueType: ValueType { .string }

    public func boolValue() -> Bool? {
        return Bool(self)
    }
    public func intValue() -> Int? {
        return Int(self)
    }
    public func doubleValue() -> Double? {
        return Double(self)
    }
    public func stringValue() -> String? {
        return self
    }
}

extension Int: ValueProtocol {
    public var valueType: ValueType { .int }
    
    public func boolValue() -> Bool? {
        return nil
    }
    public func intValue() -> Int? {
        return self
    }
    public func doubleValue() -> Double? {
        return Double(self)
    }
    public func stringValue() -> String? {
        return String(self)
    }
}

extension Bool: ValueProtocol {
    public var valueType: ValueType { .bool }

    public func boolValue() -> Bool? {
        return self
    }
    public func intValue() -> Int? {
        return nil
    }
    public func doubleValue() -> Double? {
        return nil
    }
    public func stringValue() -> String? {
        return String(self)
    }
}

extension Double: ValueProtocol {
    public var valueType: ValueType { .double }

    public func boolValue() -> Bool? {
        return nil
    }
    public func intValue() -> Int? {
        return Int(self)
    }
    public func doubleValue() -> Double? {
        return self
    }
    public func stringValue() -> String? {
        return String(self)
    }
}

extension Float: ValueProtocol {
    public var valueType: ValueType { .double }

    public func boolValue() -> Bool? {
        return nil
    }
    public func intValue() -> Int? {
        return Int(self)
    }
    public func doubleValue() -> Double? {
        return Double(self)
    }
    public func stringValue() -> String? {
        return String(self)
    }
}

