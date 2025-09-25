//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/03/2024.
//

/// ValueType specifies a data type of a value that is used in interfaces.
///
public enum AtomType: String, Equatable, Codable, CustomStringConvertible, Sendable {
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
    public func isConvertible(to other: AtomType) -> Bool {
        switch (self, other) {
        // Bool to string, int or itself only
        case (.bool,   .string): return true
        case (.bool,   .bool):   return true
        case (.bool,   .int):    return true
        case (.bool,   .double): return false
        case (.bool,   .point):  return false

        // Int to all except point
        case (.int,    .string): return true
        case (.int,    .bool):   return true
        case (.int,    .int):    return true
        case (.int,    .double): return true
        case (.int,    .point):  return false

        // Double to string or to itself
        case (.double, .string): return true
        case (.double, .bool):   return false
        case (.double, .int):    return true // not always
        case (.double, .double): return true
        case (.double, .point):  return false

        // String to all except point
        case (.string, .string): return true
        case (.string, .bool):   return true
        case (.string, .int):    return true
        case (.string, .double): return true
        case (.string, .point):  return false

        // Point to string or itself
        case (.point, .string): return true
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

/// VariantAtom represents a scalar or a simple tuple-like value.
///
/// Atoms can be: integers, double precision floating points, booleans,
/// strings or 2D points.
///
/// - SeeAlso: ``Variant``
///
public enum VariantAtom: Equatable, CustomStringConvertible, Hashable, Sendable {
    /// Representation of an integer.
    case int(Int)
    
    /// Representation of a double precision floating point value.
    case double(Double)
    
    /// Representation of a text string.
    case string(String)
    
    /// Representation of a boolean value.
    case bool(Bool)
    
    /// Representation of a 2D point value.
    case point(Point)
    
    public init?(any value: Any) {
        switch value {
        case let value as Int: self = .int(value)
        case let value as Double: self = .double(value)
        case let value as Bool: self = .bool(value)
        case let value as String: self = .string(value)
        case let value as Point: self = .point(value)
        default: return nil
        }
    }
    
    
    /// Flag whether the value is numeric - either an integer or a double
    /// value.
    ///
    /// - Note: String is not considered a numeric value even if it contains
    ///         a value representable as numeric.
    ///
    public var isNumeric: Bool {
        switch self {
        case .int: true
        case .double: true
        case .string: false
        case .bool: false
        case .point: false
        }
    }
    
    public var isFiniteNumber: Bool {
        switch self {
        case .int: true
        case .double(let value): value.isFinite
        case .string: false
        case .bool: false
        case .point: false
        }
    }
    
    public var isZero: Bool {
        switch self {
        case .int(let value): value == 0
        case .double(let value): value.isZero
        case .string: false
        case .bool: false
        case .point: false
        }
    }
    
    public var valueType: AtomType {
        switch self {
        case .int: .int
        case .double: .double
        case .string: .string
        case .bool: .bool
        case .point: .point
        }
    }
    
    /// Create a variant representing an integer value.
    ///
    public init(_ value: Int) {
        self = .int(value)
    }
    
    /// Create a variant representing a double value.
    ///
    public init(_ value: Double) {
        self = .double(value)
    }
    
    /// Create a variant representing a boolean value.
    ///
    public init(_ value: Bool) {
        self = .bool(value)
    }
    
    /// Create a variant representing a string value.
    ///
    public init(_ value: String) {
        self = .string(value)
    }
    
    /// Create a variant representing a 2D point value.
    ///
    public init(_ value: Point) {
        self = .point(value)
    }
    
    /// Create a variant representing an object ID.
    ///
    init(_ id: ObjectID) {
        self = .string(id.stringValue)
    }
    
    /// Check whether the atom value is convertible to a given value type.
    ///
    /// See ``Variant/isConvertible(to:)`` for more information.
    ///
    public func isConvertible(to type: ValueType) -> Bool {
        switch (self, type) {
            // Bool to string, int or itself only
        case (.bool,   .atom(.string)): true
        case (.bool,   .atom(.bool)):   true
        case (.bool,   .atom(.int)):    true
        case (.bool,   .atom(.double)): false
        case (.bool,   .atom(.point)):  false
        case (.bool,   .array(_)):      false
            
            // Int to all except point
        case (.int,    .atom(.string)): true
        case (.int,    .atom(.bool)):   true
        case (.int,    .atom(.int)):    true
        case (.int,    .atom(.double)): true
        case (.int,    .atom(.point)):  false
        case (.int,    .array(_)):      false
            
            // Double to string or to itself
        case (.double, .atom(.string)): true
        case (.double, .atom(.bool)):   false
        case (.double, .atom(.int)):    true // not lossless
        case (.double, .atom(.double)): true
        case (.double, .atom(.point)):  false
        case (.double, .array(_)):      false
            
            // String to all except array
        case (.string, .atom(.string)): true
        case (.string, .atom(.bool)):   (try? boolValue()) != nil
        case (.string, .atom(.int)):    (try? intValue()) != nil
        case (.string, .atom(.double)): (try? doubleValue()) != nil
        case (.string, .atom(.point)):  (try? pointValue()) != nil
        case (.string, .array(_)):      false
            
            // Point to string or itself
        case (.point, .atom(.string)): true
        case (.point, .atom(.bool)):   false
        case (.point, .atom(.int)):    false
        case (.point, .atom(.double)): false
        case (.point, .atom(.point)):  true
            
        case (.point, .array(.string)): true
        case (.point, .array(.bool)):   false
        case (.point, .array(.int)):    true
        case (.point, .array(.double)): true
        case (.point, .array(.point)):  false
        }
    }
    
    /// Try to get an int value from the atom value. Convert if necessary.
    ///
    /// Any type of value is attempted for conversion.
    ///
    /// - Throws ``ValueError`` if the value
    ///   can not be converted to int.
    ///
    public func intValue() throws (ValueError) -> Int {
        switch self {
        case let .int(value): return value
        case let .double(value): return Int(value)
        case let .string(value):
            if let value = Int(value){
                return value
            }
            else {
                throw ValueError.conversionFailed(.string, .int)
            }
        case let .bool(value): return value ? 1 : 0
        case .point(_): throw ValueError.notConvertible(.point, .int)
        }
    }
    
    /// Try to get a double value from the atom value. Convert if necessary.
    ///
    /// Boolean and ID values can not be converted to double.
    ///
    /// - Throws ``ValueError`` if the value
    ///   can not be converted to double.
    ///
    public func doubleValue() throws (ValueError) -> Double  {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        case .string(let value):
            if let value = Double(value){
                return value
            }
            else {
                throw ValueError.conversionFailed(.string, .double)
            }
        case .bool(_): throw ValueError.notConvertible(.bool, .double)
        case .point(_): throw ValueError.notConvertible(.point, .double)
        }
    }
    
    /// Get a string value from the atom value. Convert if necessary.
    ///
    /// All values can be converted into a string.
    ///
    /// The boolean value is converted to a string as `true` or `false` depending
    /// whether the value is true or false respectively.
    ///
    /// String representation of a point value is two numbers in square brackets
    /// separated by a comma: `[x, y]`. It is an equivalent to a JSON array of
    /// two JSON numbers.
    ///
    /// - Throws: ``ValueError`` if the value can not be converted to a point.
    /// - SeeAlso: [JSON RFC Specification](https://www.rfc-editor.org/rfc/rfc8259)
    ///
    public func stringValue() -> String {
        switch self {
        case let .int(value): return String(value)
        case let .double(value): return String(value)
        case let .string(value): return String(value)
        case let .bool(value): return String(value)
        case let .point(value): return "[\(value.x),\(value.y)]"
        }
    }
    
    /// Try to get a bool value from the  atom value. Convert if necessary.
    ///
    /// For integers the value is `true` if the integer is non-zero, if it is
    /// zero, then the boolean value is `false`.
    ///
    /// String values `"true"` and `"false"` represent corresponding boolean
    /// values `true` and `false` respectively. Any other string value
    /// causes an error.
    ///
    /// Other values can not be converted to boolean.
    ///
    /// - Throws ``ValueError`` if the value
    ///   can not be converted to bool or ``ValueError/notConvertible(_:_:)``
    ///   if the string value contains a string that is not recognised as
    ///   a valid boolean value.
    ///
    public func boolValue() throws (ValueError) -> Bool {
        switch self {
        case .int(let value): return (value != 0)
        case .double(_): throw ValueError.notConvertible(.double, .bool)
        case .string(let value): switch value {
        case "true": return true
        case "false": return false
        default: throw ValueError.conversionFailed(.string, .bool)
        }
        case .bool(let value): return value
        case .point(_): throw ValueError.notConvertible(.double, .bool)
        }
    }
    
    /// Try to get a 2D point value from the atom value. Convert if necessary.
    ///
    /// Only a point value and certain string values can be converted to a point.
    ///
    /// String representation of a point value is two numbers in square brackets
    /// separated by a comma: `[x, y]`. It is an equivalent to a JSON array of
    /// two JSON numbers.
    ///
    /// - Throws: ``ValueError`` if the value can not be converted to a point.
    /// - SeeAlso: [JSON RFC Specification](https://www.rfc-editor.org/rfc/rfc8259)
    ///
    public func pointValue() throws (ValueError) -> Point  {
        switch self {
        case .int(_): throw ValueError.notConvertible(.int, .point)
        case .double(_): throw ValueError.notConvertible(.double, .point)
        case .string(let value):
            guard let match = value.wholeMatch(of: VariantAtom.PointRegex) else {
                throw ValueError.conversionFailed(.string, .point)
            }
            guard let x = Double(match.1), let y = Double(match.2) else {
                throw ValueError.conversionFailed(.string, .point)
            }
            
            return Point(x: x, y: y)
        case .bool(_): throw ValueError.notConvertible(.bool, .point)
        case .point(let value): return value
        }
    }
    
    // Note: Do not make public. We do not want users to store IDs in unmanaged way.
    func IDValue() throws (ValueError) -> ObjectID {
        // NOTE: We are allowing conversion from double only because the Decoder
        // does not allow us to get a type of a value and decode accordingly.
        // Therefore the single value decoding tries double first before Int
        
        switch self {
        case let .int(value):
            guard let value = UInt64(exactly: value) else {
                throw ValueError.conversionToIDFailed(.int)
            }
            return ObjectID(rawValue: value)
        case .double(_): throw ValueError.conversionToIDFailed(.double)
        case let .string(value):
            if let value = ObjectID(value){
                return value
            }
            else {
                throw ValueError.conversionToIDFailed(.string)
            }
        case .bool(_): throw ValueError.conversionToIDFailed(.bool)
        case .point(_): throw ValueError.conversionToIDFailed(.point)
        }
    }
    
    /// Make a single-element array from the atom
    public func makeArray() -> Variant {
        switch self {
        case .int(let value): .array(.int([value]))
        case .double(let value):  .array(.double([value]))
        case .string(let value):  .array(.string([value]))
        case .bool(let value):  .array(.bool([value]))
        case .point(let value):  .array(.point([value]))
        }
    }
    
    public var description: String {
        stringValue()
    }

    /// Compare the atom with the other atom vaguely.
    ///
    /// Used for non-strict ordering of items, preferably using integers. However, since we can not
    /// guarantee that the content will be always correct, we fail back to some reasonable default
    /// comparisons.
    ///
    /// Rules:
    /// - Both ints and both doubles are compared as they are.
    /// - Mixed int and double are first converted to double then compared.
    /// - Strings are compared using default string comparison.
    /// - Points are compared by length.
    /// - Bool and non-comparable types are not comparable, therefore the result is `nil`.
    ///
    public func vaguelyInAscendingOrder(after other: VariantAtom) -> Bool? {
        switch (self, other){
        case let (.int(lvalue), .int(rvalue)): lvalue > rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) > rvalue
        case let (.double(lvalue), .double(rvalue)): lvalue > rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue > Double(rvalue)
        case let (.string(lvalue), .string(rvalue)): lvalue > rvalue
        case let (.point(lvalue), .point(rvalue)): lvalue.length > rvalue.length
        default: nil
        }
    }
    /// Returns `true` if the values can be compared in terms of their order.
    ///
    /// Comparable atoms:
    /// - Two ints and two doubles are comparable.
    /// - Mixed int and double is comparable with conversion of the int to double.
    /// - Two strings are comparable with each other.
    /// - Two points are comparable.
    /// - Other types and mixed types are not comparable.
    ///
    /// - SeeAlso: ``vaguelyInAscendingOrder(after:)``
    ///
    public func isVaguelyComparable(to other: VariantAtom) -> Bool {
        switch (self, other) {
        case (.int, .int): true
        case (.int, .double): true
        case (.double, .int): true
        case (.double, .double): true
        case (.string, .string): true
        case (.point, .point): true
        default: false
        }
    }

}

extension VariantAtom: Codable {
    // Use default implementation.
    // NOTE: Do not use Codable for anything public (import/export).
    // NOTE: For JSON that is to be exported/imported use custom JSON methods.
}
