//
//  File.swift
//
//
//  Created by Stefan Urbanek on 2020/12/14.
//

public typealias Point = SIMD2<Double>

/// ValueType specifies a data type of a value that is used in interfaces.
///
public enum AtomType: String, Equatable, Codable, CustomStringConvertible {
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
        // Bool to string, not to int or float
        case (.bool,   .string): return true
        case (.bool,   .bool):   return true
        case (.bool,   .int):    return false
        case (.bool,   .double): return false
        case (.bool,   .point):  return false

        // Int to all except bool
        case (.int,    .string): return true
        case (.int,    .bool):   return false
        case (.int,    .int):    return true
        case (.int,    .double): return true
        case (.int,    .point):  return false

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

public enum ValueType: Equatable, Codable, CustomStringConvertible {
    case atom(AtomType)
    case array(AtomType)
    
    public static let bool    = atom(.bool)
    public static let int     = atom(.int)
    public static let double  = atom(.double)
    public static let string  = atom(.string)
    public static let point   = atom(.point)
    
    public static let bools   = array(.bool)
    public static let ints    = array(.int)
    public static let doubles = array(.double)
    public static let strings = array(.string)
    public static let points  = array(.point)

    public var isAtom: Bool {
        switch self {
        case .atom: true
        case .array: false
        }
    }

    public var isArray: Bool {
        switch self {
        case .atom: false
        case .array: true
        }
    }
    
    public var description: String {
        switch self {
        case .atom(let value): "\(value)"
        case .array(let value): "array<\(value)>"
        }
    }
}



/// Error thrown when trying to convert a variant to a particular type.
///
public enum ValueError: Error, CustomStringConvertible{
    /// A tuple of (given, expected) for an error thrown when the given value
    /// is not convertible to the expected type.
    case typeMismatch(String, String)
    
    /// Error thrown when a value is not convertible to a boolean.
    ///
    case invalidBooleanValue(String)
    
    public var description: String {
        switch self {
        case .typeMismatch(let given, let expected): "\(given) is not convertible to \(expected) type."
        case .invalidBooleanValue(let value): "Value '\(value)' is not a valid boolean value."
        }
    }
}

// TODO: Distinguish different typed value retrieval (see note below)
/*
    - intValue: Int
    - asInt() throws -> Int
 
 */

/// VariantAtom represents a scalar or a simple tuple-like value.
///
/// Atoms can be: integers, double precision floating points, booleans,
/// strings or 2D points.
///
/// - SeeAlso: ``Variant``
///
public enum VariantAtom: Equatable, CustomStringConvertible {
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
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the value
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
                throw ValueError.typeMismatch(value, "int")
            }
        case let .bool(value): return value ? 1 : 0
        case let .point(value): throw ValueError.typeMismatch("\(value)", "int")
        }
    }

    /// Try to get a double value from the atom value. Convert if necessary.
    ///
    /// Boolean and ID values can not be converted to double.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the value
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
                throw ValueError.typeMismatch(value, "double")
            }
        case .bool(let value): throw ValueError.typeMismatch("\(value)", "double")
        case let .point(value): throw ValueError.typeMismatch("\(value)", "double")
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
        case let .point(value): return "\(value.x)x\(value.y)"
//        case let .point(value): throw ValueError.typeMismatch("\(value)", "string")
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
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the value
    ///   can not be converted to bool or ``ValueError/invalidBooleanValue(_:)``
    ///   if the string value contains a string that is not recognised as
    ///   a valid boolean value.
    ///
    public func boolValue() throws -> Bool {
        switch self {
        case .int(let value): return (value != 0)
        case .double(let value): throw ValueError.typeMismatch("\(value)", "bool")
        case .string(let value): switch value {
                                    case "true": return true
                                    case "false": return false
                                    default: throw ValueError.invalidBooleanValue(value)
                                    }
        case .bool(let value): return value
        case let .point(value): throw ValueError.typeMismatch("\(value)", "bool")
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
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the value
    ///   can not be converted to point.
    ///
    /// - Note: In the future the point format might change or support different
    ///   formats.
    ///
    public func pointValue() throws -> Point  {
        switch self {
        case .int(let value): throw ValueError.typeMismatch("\(value)", "point")
        case .double(let value): throw ValueError.typeMismatch("\(value)", "point")
        case .string(let value):
            let split = value.split(separator: "x", maxSplits: 2)
            guard split.count == 2 else {
                throw ValueError.typeMismatch("\(value)", "point")
            }
            guard let x = Double(split[0]),
                  let y = Double(split[1]) else {
                throw ValueError.typeMismatch("\(value)", "point")
            }
            return Point(x: x, y: y)
        case .bool(let value): throw ValueError.typeMismatch("\(value)", "point")
        case .point(let value): return value
        }
    }

    func IDValue() throws -> ObjectID {
        // FIXME: Do not allow conversion from Double (see note below)
        // NOTE: We are allowing conversion from double only because the Decoder
        // does not allow us to get a type of a value and decode accordingly.
        // Therefore the single value decoding tries double first before Int
        
        switch self {
        case let .int(value): return ObjectID(value)
        case let .double(value): return ObjectID(value)
//        case let .double(value): throw ValueError.typeMismatch(String(value), "ID")
        case let .string(value):
            if let value = ObjectID(value){
                return value
            }
            else {
                throw ValueError.typeMismatch(value, "ID")
            }
        case let .bool(value): throw ValueError.typeMismatch(String(value), "ID")
        case let .point(value): throw ValueError.typeMismatch("\(value)", "ID")
        }
    }
    
    public var description: String {
        stringValue()
    }
}

extension VariantAtom: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value: Int = try? container.decode(Int.self) {
            self = .int(value)
        }
        else if let value: Double = try? container.decode(Double.self) {
            self = .double(value)
        }
        else if let value: Bool = try? container.decode(Bool.self) {
            self = .bool(value)
        }
        else if let value: Point = try? container.decode(Point.self) {
            self = .point(value)
        }
        else {
            let value: String = try container.decode(String.self)
            self = .string(value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .point(value): try container.encode(value)
        }
    }
    
    public func anyValue() -> Any {
        switch self {
        case let .int(value): return value
        case let .double(value): return value
        case let .string(value): return value
        case let .bool(value): return value
        case let .point(value): return value
        }
    }

}

/// Variant holds a value of different core data types.
///
/// Variant values can be: integers, double precision floating points, booleans,
/// strings or 2D points. They can also be arrays of any of the
/// atom values, where all the items of the array are the same.
///
/// - SeeAlso: ``ValueAtom``
///
public enum Variant: Equatable, CustomStringConvertible {
    case atom(VariantAtom)
    case array([VariantAtom])

    public init?(any value: Any) {
        switch value {
        case let value as Int: self = .atom(.int(value))
        case let value as Double: self = .atom(.double(value))
        case let value as Bool: self = .atom(.bool(value))
        case let value as String: self = .atom(.string(value))
        case let value as Point: self = .atom(.point(value))
        case let values as [Int]: self = .array(values.map { VariantAtom.int($0)})
        case let values as [Double]: self = .array(values.map { VariantAtom.double($0)})
        case let values as [Bool]: self = .array(values.map { VariantAtom.bool($0)})
        case let values as [String]: self = .array(values.map { VariantAtom.string($0)})
        case let values as [Point]: self = .array(values.map { VariantAtom.point($0)})
        default: return nil
        }
    }
    /// Create an atom wrapping an integer value.
    ///
    public init(_ value: Int) {
        self = .atom(.int(value))
    }

    /// Create an atom wrapping a double value.
    ///
    public init(_ value: Double) {
        self = .atom(.double(value))
    }

    /// Create an atom wrapping a boolean value.
    ///
    public init(_ value: Bool) {
        self = .atom(.bool(value))
    }

    /// Create an atom wrapping a string value.
    ///
    public init(_ value: String) {
        self = .atom(.string(value))
    }

    /// Create an atom wrapping a 2D point value.
    ///
    public init(_ value: Point) {
        self = .atom(.point(value))
    }

    public init(_ values: [Double]) {
        self = .array(values.map { VariantAtom.double($0)} )
    }

    /// Create an atom wrapping a list of strings
    ///
    public init(_ values: [String]) {
        self = .array(values.map { VariantAtom.string($0)} )
    }
    
    /// Create an atom wrapping a list of points
    ///
    public init(_ values: [Point]) {
        self = .array(values.map { VariantAtom.point($0)} )
    }

    /// Flag that indicates whether the value is a numeric value. Numeric
    /// values are only integers and doubles.
    ///
    /// - SeeAlso: ``ValueAtom/isNumeric``.
    ///
    public var isNumeric: Bool {
        switch self {
        case .atom(let value): value.isNumeric
        case .array: false
        }
    }

    public var isArray: Bool {
        switch self {
        case .atom: false
        case .array: true
        }
    }

    public var valueType: ValueType? {
        switch self {
        case .atom(let value): return .atom(value.valueType)
        case .array(let items):
            if let first = items.first {
                return .array(first.valueType)
            }
            else {
                return nil
            }
        }
    }
    
    /// Return an underlying atom value type or `nil` if the variant
    /// is an array.
    ///
    public var atomType: AtomType? {
        switch self {
        case .atom(let value): value.valueType
        case .array: nil
        }
    }
    
    public var arrayItemType: AtomType? {
        switch self {
        case .atom: nil
        case .array(let items): items.first?.valueType
        }
    }

    /// Get all items as ``ValueAtom``s if the variant type is an array.
    ///
    public var items: [VariantAtom]? {
        switch self {
        case .atom: nil
        case .array(let items): items
        }
    }

    /// Try to get an int value from the variant. Convert if necessary.
    ///
    /// Any type of variant is attempted for conversion.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the variant
    ///   can not be converted to int.
    ///
    /// - SeeAlso: ``VariantAtom/intValue()``
    ///
    public func intValue() throws -> Int {
        switch self {
        case .atom(let value): return try value.intValue()
        case .array: throw ValueError.typeMismatch("Array", "int")
        }
    }

    /// Get a string value from the variant. Convert if necessary.
    ///
    /// All variants can be converted into a string. Arrays
    /// can not be converted to a string.
    ///
    /// The boolean value is converted to a string as `true` or `false` depending
    /// whether the value is true or false respectively.
    ///
    /// The point value is converted to a string with the `x` character as
    /// point component value separator, so for example point `Point(x:10, y:20)`
    /// is represented as string as `"10.0x20.0"` (note that the point components
    /// are doubles)
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an array.
    ///
    /// - SeeAlso: ``VariantAtom/stringValue()``
    ///
    public func stringValue() throws -> String {
        switch self {
        case .atom(let value): return value.stringValue()
        case .array: throw ValueError.typeMismatch("Array", "string")
        }
    }

    /// Try to get a bool value from the variant. Convert if necessary.
    ///
    /// For integers the value is `true` if the integer is non-zero, if it is
    /// zero, then the boolean value is `false`.
    ///
    /// String values `"true"` and `"false"` represent corresponding boolean
    /// values `true` and `false` respectively. Any other string value
    /// causes an error.
    ///
    /// Other variants can not be converted to boolean.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the variant
    ///   can not be converted to bool or ``ValueError/invalidBooleanValue(_:)``
    ///   if the string value contains a string that is not recognised as
    ///   a valid boolean value. ``ValueError/typeMismatch(_:_:)`` when the
    ///   variant is an array.
    ///
    /// - SeeAlso: ``VariantAtom/boolValue()``
    ///
    public func boolValue() throws -> Bool {
        switch self {
        case .atom(let value): return try value.boolValue()
        case .array: throw ValueError.typeMismatch("Array", "bool")
        }
    }

    /// Try to get a double value from the variant. Convert if necessary.
    ///
    /// Boolean and ID values can not be converted to double.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the variant
    ///   can not be converted to double or is an array.
    ///
    /// - SeeAlso: ``VariantAtom/doubleValue()``
    ///
    public func doubleValue() throws -> Double {
        switch self {
        case .atom(let value): return try value.doubleValue()
        case .array: throw ValueError.typeMismatch("Array", "double")
        }
    }
    
    /// Try to get a 2D point value from the variant. Convert if necessary.
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
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an array or the atom is not a point or convertible to a point.
    ///
    /// - SeeAlso: ``VariantAtom/pointValue()``
    ///
    /// - Note: In the future the point format might change or support different
    ///   formats.
    ///
    public func pointValue() throws -> Point {
        switch self {
        case .atom(let value): return try value.pointValue()
        case .array(let items):
            if items.count == 2 {
                let x = try items[0].doubleValue()
                let y = try items[1].doubleValue()
                return Point(x: x, y: y)
            }
            throw ValueError.typeMismatch("Array of \(items.count) items", "point")
        }
    }

    func IDValue() throws -> ObjectID {
        switch self {
        case .atom(let value): return try value.IDValue()
        case .array(let items):
            throw ValueError.typeMismatch("Array of \(items.count) items", "ID")
        }

    }
    
    func IDArray() throws -> [ObjectID] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "array of IDs")
        case .array(let items):
            return try items.map { try $0.IDValue() }
        }

    }

    
    /// Converts the variant into a list of integers.
    ///
    /// All elements of the list must be an integer.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an atom or when any of the values can not be converted to an
    ///   integer.
    ///
    /// - SeeAlso: ``intValue()``, ``VariantAtom/intValue()``
    ///
    public func intArray() throws -> [Int] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "array of ints")
        case .array(let values):
            return try values.map { try $0.intValue() }
        }
    }

    /// Converts the variant into a list of strings.
    ///
    /// The elements might be of any type, since any type is convertible
    /// to a string.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an atom.
    ///
    /// - SeeAlso: ``stringValue()``, ``VariantAtom/stringValue()``
    ///
    public func stringArray() throws -> [String] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "array of strings")
        case .array(let values):
            return values.map { $0.stringValue() }
        }
    }

    /// Converts the variant into a list of booleans.
    ///
    /// All elements of the list must be a boolean.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an atom or when any of the values can not be converted to a
    ///   boolean.
    ///
    /// - SeeAlso: ``boolValue()``, ``VariantAtom/boolValue()``
    ///
    public func boolArray() throws -> [Bool] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "array of bools")
        case .array(let values):
            return try values.map { try $0.boolValue() }
        }
    }
    
    /// Converts the variant into a list of doubles.
    ///
    /// All elements of the list must be a double.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an atom or when any of the values can not be converted to a
    ///   double.
    ///
    /// - SeeAlso: ``doubleValue()``, ``VariantAtom/doubleValue()``
    ///
    public func doubleArray() throws -> [Double] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "array of doubles")
        case .array(let values):
            return try values.map { try $0.doubleValue() }
        }
    }
    /// Converts the variant into a list of points.
    ///
    /// All elements of the list must be a point.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the variant
    ///   is an atom or when any of the values can not be converted to a
    ///   point.
    ///
    /// - SeeAlso: ``pointValue()``, ``VariantAtom/pointValue()``
    ///
    public func pointArray() throws -> [Point] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "array of points")
        case .array(let values):
            return try values.map { try $0.pointValue() }
        }
    }

    public func anyValue() -> Any {
        switch self {
        case .atom(let value): return value.anyValue
        case .array(let values):
            return Array(values.map { $0.anyValue })
        }

    }
    
    public var description: String {
        switch self {
        case .atom(let value):
            return value.description
        case .array(let array):
            let arrayStr = array.map { $0.description }
                            .joined(separator:", ")
            return "[\(arrayStr)]"
        }
    }
}

extension Variant: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        do {
            let values: [Double] = try container.decode(Array<Double>.self)
            self = .array(values.map { .double($0) })
            return
        }
        catch is DecodingError {
        }

        do {
            let values: [Point] = try container.decode(Array<Point>.self)
            self = .array(values.map { .point($0) })
            return
        }
        catch is DecodingError {
        }

        do {
            let value: VariantAtom = try container.decode(VariantAtom.self)
            self = .atom(value)
            return
        }
        catch is DecodingError {
            // We are fine, let us try another one.
        }

        // We are not catching error of the last one and let it go through.
        
        let values: [String] = try container.decode(Array<String>.self)
        self = .array(values.map { .string($0) })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .atom(let atom): try container.encode(atom)
        case .array(let array): try container.encode(array)
        }
    }
}

extension Variant: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .atom(.int(value))
    }
    
    public typealias IntegerLiteralType = Int
}

extension Variant: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .atom(.double(value))
    }
    
    public typealias FloatLiteralType = Double
}
extension Variant: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .atom(.string(value))
    }
}
