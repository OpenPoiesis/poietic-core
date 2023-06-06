//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 2020/12/14.
//

// TODO: Use ValueProtocol and then Something.asValue

/// Protocol for objects that can be represented as ``Value``.
///
public protocol ValueProtocol: Hashable {
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
    public func isEqual(to other: any ValueProtocol) -> Bool {
        guard self.valueType == other.valueType else {
            return false
        }
        switch self.valueType {
        case .bool: return self.boolValue() == other.boolValue()
        case .int: return self.intValue() == other.intValue()
        case .double: return self.doubleValue() == other.doubleValue()
        case .string: return self.stringValue() == other.stringValue()
        }
    }
}

/// ValueType specifies a data type of a value that is used in interfaces.
///
public enum ValueType: String, Equatable, Codable, CustomStringConvertible {
    case bool
    case int
    case double
    case string
    // TODO: case date
    
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

        // Int to all except bool
        case (.int,    .string): return true
        case (.int,    .bool):   return false
        case (.int,    .int):    return true
        case (.int,    .double): return true

        // Float to all except bool
        case (.double, .string): return true
        case (.double, .bool):   return false
        case (.double, .int):    return true
        case (.double, .double): return true

        // String to all
        case (.string, .string): return true
        case (.string, .bool):   return true
        case (.string, .int):    return true
        case (.string, .double): return true
        }
    }
    
    public var description: String {
        switch self {
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .string: return "string"
        }
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

