//
//  File.swift
//
//
//  Created by Stefan Urbanek on 2020/12/14.
//


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
    
    public func isConvertible(to other: ValueType) -> Bool {
        switch (self, other) {
        case (.atom(let lhs), .atom(let rhs)):
            lhs.isConvertible(to: rhs)
        case (.atom(_), .array(_)):
            // TODO: Point?
            false
        case (.array(_), .atom(_)):
            // TODO: Point?
            false
        case (.array(let lhs), .array(let rhs)):
            lhs.isConvertible(to: rhs)
        }
    }
    
    public func isConvertible(to other: UnionType) -> Bool {
        switch other {
        case .any: true
        case .concrete(let otherType): isConvertible(to: otherType)
        case .union(let types): types.contains { isConvertible(to: $0) }
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
public struct TypeError: Error, CustomStringConvertible{
    /// Type that was expected.
    public let required: String
    /// Type that was provided.
    public let provided: String
    
    public init(required: String, provided: String) {
        self.required = required
        self.provided = provided
    }
    
    public var description: String {
        "Type error: required '\(required)', provided '\(provided)'"
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
    case array(VariantArray)

    public init?(any value: Any) {
        switch value {
        case let value as Int: self = .atom(.int(value))
        case let value as Double: self = .atom(.double(value))
        case let value as Bool: self = .atom(.bool(value))
        case let value as String: self = .atom(.string(value))
        case let value as Point: self = .atom(.point(value))
        case let values as [Int]: self = .array(.int(values))
        case let values as [Double]: self = .array(.double(values))
        case let values as [Bool]: self = .array(.bool(values))
        case let values as [String]: self = .array(.string(values))
        case let values as [Point]: self = .array(.point(values))
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

    public init(_ values: [Int]) {
        self = .array(.int(values))
    }

    public init(_ values: [Double]) {
        self = .array(.double(values))
    }
    public init(_ values: [Bool]) {
        self = .array(.bool(values))
    }

    /// Create an atom wrapping a list of strings
    ///
    public init(_ values: [String]) {
        self = .array(.string(values))
    }
    
    /// Create an atom wrapping a list of points
    ///
    public init(_ values: [Point]) {
        self = .array(.point(values))
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

    public var valueType: ValueType {
        switch self {
        case .atom(let value): return .atom(value.valueType)
        case .array(let values): return .array(values.itemType)
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
        case .array(let array): array.itemType
        }
    }

    /// Get all items as ``ValueAtom``s if the variant type is an array.
    ///
    @available(*, deprecated, message: "REFACTORING: Check whether we can use raw array (not deprecated, really)")
    public var items: [VariantAtom]? {
        switch self {
        case .atom: nil
        case .array(let array): array.items
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
        case .array: throw TypeError(required: "int", provided: "bool")
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
        case .array: throw TypeError(required: "string", provided: "bool")
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
        case .array: throw TypeError(required: "bool", provided: "bool")
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
        case .array: throw TypeError(required: "double", provided: "array")
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
    /// - Throws: ``TypeError`` when the variant
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
        case .array(let array):
            switch array {
            case .double(let items):
                guard items.count == 2 else {
                    throw TypeError(required: "point or array of two numbers", provided: "array of \(items.count) ints")
                }
                return Point(x: items[0], y: items[1])
            case .int(let items):
                guard items.count == 2 else {
                    throw TypeError(required: "point or array of two numbers", provided: "array of \(items.count) doubles")
                }
                return Point(x: Double(items[0]), y: Double(items[1]))
            default:
                throw TypeError(required: "point or array of two numbers", provided: "array of \(array.count) non-numeric items")
            }
        }
    }

    func IDValue() throws -> ObjectID {
        switch self {
        case .atom(let value): return try value.IDValue()
        case .array(_):
            throw TypeError(required: "Object ID", provided: "array")
        }

    }
    
    @available(*, deprecated, message: "REFACTORING: We need to get rid of this")
    func IDArray() throws -> [ObjectID] {
        switch self {
        case .atom(let value):
            throw TypeError(required: "array of Object IDs", provided: "\(value.valueType)")
        case .array(let array):
            return try array.items.map { try $0.IDValue() }
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
            throw TypeError(required: "array of ints", provided: "\(value.valueType)")
        case .array(let array):
            switch array {
            case .int(let values): return values
            case .double(let values): return values.map { Int($0) }
            default:
                throw TypeError(required: "array of ints", provided: "array of \(array.itemType)")
            }
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
            throw TypeError(required: "array of strings", provided: "\(value.valueType)")
        case .array(let array):
            return array.stringItems
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
            throw TypeError(required: "array of bools", provided: "\(value.valueType)")
        case .array(let array):
            switch array {
            case .bool(let values): return values
            default:
                throw TypeError(required: "array of bools", provided: "array of \(array.itemType)")
            }
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
            throw TypeError(required: "array of doubles", provided: "\(value.valueType)")
        case .array(let array):
            switch array {
            case .double(let values): return values
            default:
                throw TypeError(required: "array of doubles", provided: "array of \(array.itemType)")
            }
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
            throw TypeError(required: "array of points", provided: "\(value.valueType)")
        case .array(let array):
            switch array {
            case .point(let values): return values
            default:
                throw TypeError(required: "array of points", provided: "array of \(array.itemType)")
            }
        }
    }

    public func anyValue() -> Any {
        switch self {
        case .atom(let value): return value.anyValue
        case .array(let array):
            return Array(array.items.map { $0.anyValue })
        }

    }
    
    public var description: String {
        switch self {
        case .atom(let value):
            return value.description
        case .array(let array):
            return array.description
        }
    }
}

extension Variant: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let array: VariantArray = try? container.decode(VariantArray.self) {
            self = .array(array)
        }
        else {
            let atom: VariantAtom = try container.decode(VariantAtom.self)
            self = .atom(atom)
        }
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

extension Variant {
    public func precedes(_ other: Variant) throws -> Bool {
        switch (self, other) {
        case let (.atom(lhs), .atom(rhs)): try lhs.precedes(rhs)
        case let (.array(lhs), .array(rhs)): try lhs.precedes(rhs)
        case (.array, .atom):
            throw EvaluationError.notComparableTypes("array", "atom")
        case (.atom, .array):
            throw EvaluationError.notComparableTypes("atom", "array")
        }
    }
}
