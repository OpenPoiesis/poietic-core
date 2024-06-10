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
        self = .string(String(id))
    }
    
    /// Try to get an int value from the atom value. Convert if necessary.
    ///
    /// Any type of value is attempted for conversion.
    ///
    /// - Throws ``ValueError`` if the value
    ///   can not be converted to int.
    ///
    public func intValue() throws -> Int {
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
    public func doubleValue() throws -> Double  {
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
    /// The point value is converted to a string with the `x` character as
    /// point component value separator, so for example point `Point(x:10, y:20)`
    /// is represented as string as `"10.0x20.0"` (note that the point components
    /// are doubles)
    ///
    public func stringValue() -> String {
        switch self {
        case let .int(value): return String(value)
        case let .double(value): return String(value)
        case let .string(value): return String(value)
        case let .bool(value): return String(value)
        // FIXME: Remove this conversion, replace with JSON
        case let .point(value): return "\(value.x)x\(value.y)"
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
    ///   can not be converted to bool or ``ValueError/invalidBooleanValue(_:)``
    ///   if the string value contains a string that is not recognised as
    ///   a valid boolean value.
    ///
    public func boolValue() throws -> Bool {
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
    
    // FIXME: Remove the 10x20 string representation and replace with JSON-compatible
    /// Try to get a 2D point value from the atom value. Convert if necessary.
    ///
    /// Only a point value and certain string values can be converted to a point.
    ///
    /// The point value is represented as a string with the `x` character as
    /// point component value separator, so for example point `Point(x:10, y:20)`
    /// is represented as string as `"10.0x20.0"` (note that the point components
    /// are doubles). The conversion is as follows:
    ///
    /// - The string is split at the first `x` character
    /// - If there are not exactly two values - an error is thrown
    /// - Each of the two values is converted to a double, if the conversion fails
    ///   an error is thrown.
    /// - The first value is the `x` component of the point and the second value
    ///   is the `y` component of the point.
    ///
    /// - Throws ``ValueError`` if the value
    ///   can not be converted to point.
    ///
    /// - Note: In the future the point format might change or support different
    ///   formats.
    ///
    public func pointValue() throws -> Point  {
        switch self {
        case .int(_): throw ValueError.notConvertible(.int, .point)
        case .double(_): throw ValueError.notConvertible(.double, .point)
        case .string(let value):
            let split = value.split(separator: "x", maxSplits: 2)
            guard split.count == 2 else {
                throw ValueError.conversionFailed(.string, .point)
            }
            guard let x = Double(split[0]),
                  let y = Double(split[1]) else {
                throw ValueError.conversionFailed(.string, .point)
            }
            return Point(x: x, y: y)
        case .bool(_): throw ValueError.notConvertible(.bool, .point)
        case .point(let value): return value
        }
    }

    // Note: Do not make public. We do not want users to store IDs in unmanaged way.
    func IDValue() throws -> ObjectID {
        // NOTE: We are allowing conversion from double only because the Decoder
        // does not allow us to get a type of a value and decode accordingly.
        // Therefore the single value decoding tries double first before Int
        
        switch self {
        case let .int(value): return ObjectID(value)
//        case let .double(value): return ObjectID(value)
        case .double(_): throw ValueError.conversionToIDFailed(.double)
        case let .string(value):
            if let value = ObjectID(value){
                return value
            }
            else {
                // TODO: We are convertible, we just failed conversion.
                throw ValueError.conversionToIDFailed(.string)
            }
        case .bool(_): throw ValueError.conversionToIDFailed(.bool)
        case .point(_): throw ValueError.conversionToIDFailed(.point)
        }
    }
    
    public var description: String {
        stringValue()
    }
}

extension VariantAtom: Codable {
    // Use default implementation.
    // NOTE: Do not use Codable for anything public (import/export).
    // NOTE: For JSON that is to be exported/imported use custom JSON methods.
}
