//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 2020/12/14.
//

// TODO: It is getting a bit messy with Point values and arrays of points. Review it.

public enum ValueError: Error, CustomStringConvertible{
    case typeMismatch(String, String)
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

/// ForeignAtom represents a scalar or a simple tuple-like value from an
/// external environment.
///
/// Foreign atoms can be: integers, double precision floating points, booleans,
/// strings, 2D points or objectIDs.
///
/// Foreign atom is typically created from values taken from outside of the
/// application or outside of the core. For example from a persistent store,
/// imported file or a pasteboard.
///
/// Foreign atom is usually not used on its own, but rather wrapped in a
/// ``ForeignValue`` that might also represent a list.
///
/// - SeeAlso: ``ForeignValue``
///
public enum ForeignAtom: Equatable, CustomStringConvertible {
    // TODO: Replace xxxValue() to cast() -> xxx
    
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
    
    /// Representation of an object ID.
    ///
    /// - Note: Currently the ID is a 64 bit integer, but it is very likely
    ///   that the ID will change to UUID or something similar.
    ///
    /// - SeeAlso: ``ObjectID``
    ///
    case id(ObjectID)

    public init?(any value: Any) {
        switch value {
        case let value as Int: self = .int(value)
        case let value as Double: self = .double(value)
        case let value as Bool: self = .bool(value)
        case let value as String: self = .string(value)
        case let value as Point: self = .point(value)
        case let value as ObjectID: self = .id(value)
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
        case .id: false
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
        case .id:
            // FIXME: IMPORTANT: We need to distinguish between internal and external value types
            fatalError("ID is an internal value type")
        }
    }

    /// Create a foreign value wrapping an integer value.
    ///
    public init(_ value: Int) {
        self = .int(value)
    }

    /// Create a foreign value wrapping a double value.
    ///
    public init(_ value: Double) {
        self = .double(value)
    }

    /// Create a foreign value wrapping a boolean value.
    ///
    public init(_ value: Bool) {
        self = .bool(value)
    }

    /// Create a foreign value wrapping a string value.
    ///
    public init(_ value: String) {
        self = .string(value)
    }

    /// Create a foreign value wrapping a 2D point value.
    ///
    public init(_ value: Point) {
        self = .point(value)
    }

    /// Create a foreign value wrapping an object ID.
    ///
    public init(_ id: ObjectID) {
        self = .id(id)
    }
    
    /// Try to get an int value from the foreign value. Convert if necessary.
    ///
    /// Any type of foreign value is attempted for conversion.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
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
        case let .id(value): return Int(value)
        case let .point(value): throw ValueError.typeMismatch("\(value)", "int")
        }
    }

    /// Try to get a double value from the foreign value. Convert if necessary.
    ///
    /// Boolean and ID values can not be converted to double.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
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
        case .id(let value): throw ValueError.typeMismatch("\(value)", "double")
        case let .point(value): throw ValueError.typeMismatch("\(value)", "double")
        }
    }
    
    /// Get a string value from the foreign value. Convert if necessary.
    ///
    /// All foreign values can be converted into a string.
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
        case let .id(value): return String(value)
        case let .point(value): return "\(value.x)x\(value.y)"
//        case let .point(value): throw ValueError.typeMismatch("\(value)", "string")
        }
    }

    /// Try to get a bool value from the foreign value. Convert if necessary.
    ///
    /// For integers the value is `true` if the integer is non-zero, if it is
    /// zero, then the boolean value is `false`.
    ///
    /// String values `"true"` and `"false"` represent corresponding boolean
    /// values `true` and `false` respectively. Any other string value
    /// causes an error.
    ///
    /// Other foreign values can not be converted to boolean.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
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
        case .id(let value): throw ValueError.typeMismatch("\(value)", "bool")
        case let .point(value): throw ValueError.typeMismatch("\(value)", "bool")
        }
    }
    
    /// Try to get an ID value from the foreign value. Convert if necessary.
    ///
    /// Only integer and string value can be converted to ID.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
    ///   can not be converted to ID.
    ///
    public func idValue() throws -> ObjectID {
        switch self {
        case .int(let value): return ObjectID(value)
        case .double(let value): throw ValueError.typeMismatch("\(value)", "ID")
        case .string(let value):
            if let value = ObjectID(value) {
                return value
            }
            else {
                throw ValueError.typeMismatch("\(value)", "ID")
            }
        case .bool(let value): throw ValueError.typeMismatch("\(value)", "ID")
        case .id(let value): return value
        case let .point(value): throw ValueError.typeMismatch("\(value)", "id")
        }
    }
    
    // FIXME: Remove the 10x20 string representation and replace with JSON-compatible
    /// Try to get a 2D point value from the foreign value. Convert if necessary.
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
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
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
        case .id(let value): throw ValueError.typeMismatch("\(value)", "point")
        case .point(let value): return value
        }
    }

    public var description: String {
        stringValue()
    }
}

extension ForeignAtom: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        do {
            let value: Double = try container.decode(Double.self)
            self = .double(value)
            return
        }
        catch is DecodingError {
            // We are fine, let us try another one.
        }
        
        do {
            let value: Int = try container.decode(Int.self)
            self = .int(value)
            return
        }
        catch is DecodingError {
            // We are fine, let us try another one.
        }
        
        do {
            let value: Bool = try container.decode(Bool.self)
            self = .bool(value)
            return
        }
        catch is DecodingError {
            // We are fine, let us try another one.
        }

        do {
            let value: Point = try container.decode(Point.self)
            self = .point(value)
            return
        }
        catch is DecodingError {
            // We are fine, let us try another one.
        }

        // We are not catching error of the last one and let it go through.

        let value: String = try container.decode(String.self)
        self = .string(value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .id(value): try container.encode(String(value))
        case let .point(value): try container.encode(value)
        }
    }
    
    public func anyValue() -> Any {
        switch self {
        case let .int(value): return value
        case let .double(value): return value
        case let .string(value): return value
        case let .bool(value): return value
        case let .id(value): return value
        case let .point(value): return value
        }
    }

}

/// ForeignValue represents a value from an external environment that can be
/// either an atom or a list of atoms – an array.
///
/// Foreign values can be: integers, double precision floating points, booleans,
/// strings, 2D points or objectIDs. They can also be arrays of any of the
/// atom values, where all the items of the array are the same.
///
/// Foreign value is typically created from values taken from outside of the
/// application or outside of the core. For example from a persistent store,
/// imported file or a pasteboard.
///
/// - SeeAlso: ``ForeignAtom``
///
/// - Note: ForeignValue is not a recursive value, it can either be an atom or a list
///   of atoms of the same type. It is highly unlikely that this value will be
///   recursive in the future.
///
public enum ForeignValue: Equatable, CustomStringConvertible {
    case atom(ForeignAtom)
    case array([ForeignAtom])

    public init?(any value: Any) {
        switch value {
        case let value as Int: self = .atom(.int(value))
        case let value as Double: self = .atom(.double(value))
        case let value as Bool: self = .atom(.bool(value))
        case let value as String: self = .atom(.string(value))
        case let value as Point: self = .atom(.point(value))
        case let value as ObjectID: self = .atom(.id(value))
        case let values as [Int]: self = .array(values.map { ForeignAtom.int($0)})
        case let values as [Double]: self = .array(values.map { ForeignAtom.double($0)})
        case let values as [Bool]: self = .array(values.map { ForeignAtom.bool($0)})
        case let values as [String]: self = .array(values.map { ForeignAtom.string($0)})
        case let values as [Point]: self = .array(values.map { ForeignAtom.point($0)})
        case let values as [ObjectID]: self = .array(values.map { ForeignAtom.id($0)})
        default: return nil
        }
    }
    /// Create a foreign value wrapping an integer value.
    ///
    public init(_ value: Int) {
        self = .atom(.int(value))
    }

    /// Create a foreign value wrapping a double value.
    ///
    public init(_ value: Double) {
        self = .atom(.double(value))
    }

    /// Create a foreign value wrapping a boolean value.
    ///
    public init(_ value: Bool) {
        self = .atom(.bool(value))
    }

    /// Create a foreign value wrapping a string value.
    ///
    public init(_ value: String) {
        self = .atom(.string(value))
    }

    /// Create a foreign value wrapping a 2D point value.
    ///
    public init(_ value: Point) {
        self = .atom(.point(value))
    }

    /// Create a foreign value wrapping an object ID.
    ///
    public init(_ id: ObjectID) {
        self = .atom(.id(id))
    }
    
    public init(_ values: [Double]) {
        self = .array(values.map { ForeignAtom.double($0)} )
    }

    /// Create a foreign value wrapping a list of strings
    ///
    public init(_ values: [String]) {
        self = .array(values.map { ForeignAtom.string($0)} )
    }
    
    /// Create a foreign value wrapping a list of points
    ///
    public init(_ values: [Point]) {
        self = .array(values.map { ForeignAtom.point($0)} )
    }

    /// Create a foreign value wrapping a list of object IDs.
    ///
    public init(ids: [ObjectID]) {
        self = .array(ids.map { ForeignAtom.id($0)} )
    }
    
    /// Flag that indicates whether the value is a numeric value. Numeric
    /// values are only integers and doubles.
    ///
    /// - SeeAlso: ``ForeignAtom/isNumeric``.
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

    /// Return an underlying atom value type or `nil` if the foreign value
    /// is an array.
    ///
    public var valueType: AtomType? {
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


    /// Try to get an int value from the foreign value. Convert if necessary.
    ///
    /// Any type of foreign value is attempted for conversion.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
    ///   can not be converted to int.
    ///
    /// - SeeAlso: ``ForeignAtom/intValue()``
    ///
    public func intValue() throws -> Int {
        switch self {
        case .atom(let value): return try value.intValue()
        case .array: throw ValueError.typeMismatch("Array", "int")
        }
    }

    /// Get a string value from the foreign value. Convert if necessary.
    ///
    /// All foreign atom values can be converted into a string. Arrays
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
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an array.
    ///
    /// - SeeAlso: ``ForeignAtom/stringValue()``
    ///
    public func stringValue() throws -> String {
        switch self {
        case .atom(let value): return value.stringValue()
        case .array: throw ValueError.typeMismatch("Array", "string")
        }
    }

    /// Try to get a bool value from the foreign value. Convert if necessary.
    ///
    /// For integers the value is `true` if the integer is non-zero, if it is
    /// zero, then the boolean value is `false`.
    ///
    /// String values `"true"` and `"false"` represent corresponding boolean
    /// values `true` and `false` respectively. Any other string value
    /// causes an error.
    ///
    /// Other foreign values can not be converted to boolean.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
    ///   can not be converted to bool or ``ValueError/invalidBooleanValue(_:)``
    ///   if the string value contains a string that is not recognised as
    ///   a valid boolean value. ``ValueError/typeMismatch(_:_:)`` when the
    ///   foreign value is an array.
    ///
    /// - SeeAlso: ``ForeignAtom/boolValue()``
    ///
    public func boolValue() throws -> Bool {
        switch self {
        case .atom(let value): return try value.boolValue()
        case .array: throw ValueError.typeMismatch("Array", "bool")
        }
    }

    /// Try to get a double value from the foreign value. Convert if necessary.
    ///
    /// Boolean and ID values can not be converted to double.
    ///
    /// - Throws ``ValueError/typeMismatch(_:_:)`` if the foreign value
    ///   can not be converted to double or is an array.
    ///
    /// - SeeAlso: ``ForeignAtom/doubleValue()``
    ///
    public func doubleValue() throws -> Double {
        switch self {
        case .atom(let value): return try value.doubleValue()
        case .array: throw ValueError.typeMismatch("Array", "double")
        }
    }
    
    /// Try to get a 2D point value from the foreign value. Convert if necessary.
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
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an array or the atom is not a point or convertible to a point.
    ///
    /// - SeeAlso: ``ForeignAtom/pointValue()``
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

    
    /// Try to get an ID value from the foreign value. Convert if necessary.
    ///
    /// Only integer and string value can be converted to ID.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an array.
    ///
    public func idValue() throws -> ObjectID {
        switch self {
        case .atom(let value): return try value.idValue()
        case .array: throw ValueError.typeMismatch("Array", "ID")
        }
    }
    
    
    /// Converts the foreign value into a list of IDs.
    ///
    /// All elements of the list must be an ID.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an atom or when any of the values can not be converted to an
    ///   ID.
    ///
    /// - SeeAlso: ``idValue()``, ``ForeignAtom/idValue()``
    ///
    public func idArray() throws -> [ObjectID] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "Array")
        case .array(let values):
            return try values.map { try $0.idValue() }
        }
    }

    /// Converts the foreign value into a list of integers.
    ///
    /// All elements of the list must be an integer.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an atom or when any of the values can not be converted to an
    ///   integer.
    ///
    /// - SeeAlso: ``intValue()``, ``ForeignAtom/intValue()``
    ///
    public func intArray() throws -> [Int] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "Array")
        case .array(let values):
            return try values.map { try $0.intValue() }
        }
    }

    /// Converts the foreign value into a list of strings.
    ///
    /// The elements might be of any type, since any type is convertible
    /// to a string.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an atom.
    ///
    /// - SeeAlso: ``stringValue()``, ``ForeignAtom/stringValue()``
    ///
    public func stringArray() throws -> [String] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "Array")
        case .array(let values):
            return values.map { $0.stringValue() }
        }
    }

    /// Converts the foreign value into a list of booleans.
    ///
    /// All elements of the list must be a boolean.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an atom or when any of the values can not be converted to a
    ///   boolean.
    ///
    /// - SeeAlso: ``boolValue()``, ``ForeignAtom/boolValue()``
    ///
    public func boolArray() throws -> [Bool] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "Array")
        case .array(let values):
            return try values.map { try $0.boolValue() }
        }
    }
    
    /// Converts the foreign value into a list of doubles.
    ///
    /// All elements of the list must be a double.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an atom or when any of the values can not be converted to a
    ///   double.
    ///
    /// - SeeAlso: ``doubleValue()``, ``ForeignAtom/doubleValue()``
    ///
    public func doubleArray() throws -> [Double] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "Array")
        case .array(let values):
            return try values.map { try $0.doubleValue() }
        }
    }
    /// Converts the foreign value into a list of points.
    ///
    /// All elements of the list must be a point.
    ///
    /// - Throws: ``ValueError/typeMismatch(_:_:)`` when the foreign value
    ///   is an atom or when any of the values can not be converted to a
    ///   point.
    ///
    /// - SeeAlso: ``pointValue()``, ``ForeignAtom/pointValue()``
    ///
    public func pointArray() throws -> [Point] {
        switch self {
        case .atom(let value):
            throw ValueError.typeMismatch("atom(\(value.valueType))", "Array")
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

extension ForeignValue: Codable {
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
            let value: ForeignAtom = try container.decode(ForeignAtom.self)
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

extension ForeignValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .atom(.int(value))
    }
    
    public typealias IntegerLiteralType = Int
}

extension ForeignValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .atom(.double(value))
    }
    
    public typealias FloatLiteralType = Double
}
extension ForeignValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .atom(.string(value))
    }
}
