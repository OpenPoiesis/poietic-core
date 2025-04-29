//
//  Variant+JSON.swift
//
//
//  Created by Stefan Urbanek on 11/07/2023.
//

/// Errors that can occur with foreign object properties or attributes.
///
public enum ForeignValueError: Error, Equatable {
    /// Value content is invalid.
    ///
    /// This error is typically thrown when:
    /// - A string value of one of multiple enum values is expected.
    /// - Inner structure of a property or an attribute is invalid and can not be processed further.
    case invalidValue
    
    /// Value is of a different type than expected. The expected type is the associated value of
    /// this case. The type is a name of a foreign interface data type, can be more descriptive
    /// and rather user-oriented.
    ///
    case typeMismatch(String)

    /// A property or an attribute is expected, but the value is not present in the foreign data
    /// or interface.
    case valueNotFound
    
    /// A value, typically an attribute value, is expected but can not be converted to a variant.
    case notConvertibleToVariant
}

extension Variant {
    public init(json: JSONValue) throws (ForeignValueError) {
        switch json {
        case let .int(value):
            self.init(value)
        case let .bool(value):
            self.init(value)
        case let .string(value):
            self.init(value)
        case let .float(value):
            self.init(value)
        case let .array(items):
            self = .array(try VariantArray(jsonItems: items))
        default:
            throw ForeignValueError.notConvertibleToVariant
        }
    }
    
    /// Create a new variant of a given type from a JSON value.
    ///
    /// The JSON value type must match required variant type. The following table describes
    /// corresponding JSON type for a given atom or an array item type:
    ///
    /// | Atom/Item Type | Required JSON type |
    /// |---|---|
    /// | bool | bool |
    /// | int | number exactly convertible to int |
    /// | double | number exactly convertible to double |
    /// | string | string |
    /// | point | two-item array with numbers exactly convertible to double |
    ///
    /// If the JSON value does not match requirements, then `nil` is returned.
    ///
    /// This initialiser is used to decode a JSON-encoded variant tuple.
    ///
    /// - SeeAlso: ``VariantAtom/init(type:json:)``, ``VariantArray/init(type:jsonItems:)``
    ///
    public init?(type: ValueType, json: JSONValue) {
        switch type {
        case let .atom(atomType):
            if let atom = VariantAtom(type: atomType, json: json) {
                self = .atom(atom)
            }
            else {
                return nil
            }
        case let .array(atomType):
            guard case let .array(items) = json else {
                return nil
            }
            if let array = VariantArray(type: atomType, jsonItems: items) {
                self = .array(array)
            }
            else {
                return nil
            }
        }
    }

    /// Get a JSON-encoded variant value.
    ///
    /// Convert the variant into a JSON-encoded value without the variant data type.
    ///
    /// The caller is expected to store the type separately.
    ///
    /// - SeeAlso: - ``init(type:json:)``
    ///
    public func asJSON() -> JSONValue {
        switch self {
        case let .atom(atom):  atom.asJSON()
        case let .array(array): array.asJSON()
        }
    }
}


extension VariantAtom {
    public init(json: JSONValue) throws (ForeignValueError) {
        switch json {
        case let .int(value):
            self.init(value)
        case let .bool(value):
            self.init(value)
        case let .string(value):
            self.init(value)
        case let .float(value):
            self.init(value)
        case let .array(items):
            guard items.count == 2 else {
                throw .notConvertibleToVariant
            }
            switch (items[0], items[1]) {
            case let (.int(x), .int(y)):
                self = .point(Point(Double(x), Double(y)))
            case let (.int(x), .float(y)):
                self = .point(Point(Double(x), y))
            case let (.float(x), .int(y)):
                self = .point(Point(x, Double(y)))
            case let (.float(x), .float(y)):
                self = .point(Point(x, y))
            default:
                throw .invalidValue
            }
        default:
            throw .notConvertibleToVariant
        }
    }

    /// Create a new variant atom of given type from JSON value.
    ///
    /// The JSON value must match required type as described in the ``Variant/init(type:json:)``.
    /// If the JSON value does not match the requirements, then `nil` is returned.
    ///
    /// This initialiser is used to decode a JSON-encoded variant tuple.
    ///
    /// - SeeAlso: ``Variant/init(type:json:)``, ``VariantArray/init(type:jsonItems:)``
    public init?(type: AtomType, json: JSONValue) {
        switch (type, json) {
        case (.int, _):
            if let value = json.exactInt() {
                self = .int(value)
            }
            else {
                return nil
            }
        case (.double, _):
            if let value = json.exactDouble() {
                self = .double(value)
            }
            else {
                return nil
            }
        case (.bool, let .bool(value)) :
            self = .bool(value)
        case (.string, let .string(value)):
            self = .string(value)
        case (.point, let .array(items)):
            guard items.count == 2 else {
                return nil
            }
            if let x = items[0].exactDouble(), let y = items[1].exactDouble() {
                self = .point(Point(x: x, y: y))
            }
            else {
                return nil
            }
        default:
            return nil
        }
    }

    public func asJSON() -> JSONValue {
        switch self {
        case let .int(value): .int(value)
        case let .double(value): .float(value)
        case let .string(value): .string(value)
        case let .bool(value): .bool(value)
        case let .point(point): .array([.float(point.x), .float(point.y)])
        }
    }
}

extension VariantArray {
    /// Create a new variant array from JSON items.
    ///
    /// The array type is decided based on the first item. The rest of the items must be of the
    /// same type.
    ///
    /// If the first item is an array, the item type is expected to be a point. All top-level items
    /// must have exactly two point components. Point components might be of any numeric type.
    ///
    /// If the list of items is empty, then a _string_ type empty array is created, as it is
    /// the most convertible type.
    ///
    public init(jsonItems items: [JSONValue]) throws (ForeignValueError) {
        if items.count == 0 {
            self = .string([])
        }

        let first = items[0]

        switch first {
        case .bool:
            var array: [Bool] = []

            for item in items {
                guard case let .bool(value) = item else {
                    throw .notConvertibleToVariant
                }
                array.append(value)
            }
            self = .bool(array)
        case .int:
            var array: [Int] = []
            for item in items {
                guard case let .int(value) = item else {
                    throw .notConvertibleToVariant
                }
                array.append(value)
            }
            self = .int(array)
        case .float:
            var array: [Double] = []
            for item in items {
                guard case let .float(value) = item else {
                    throw .notConvertibleToVariant
                }
                array.append(value)
            }
            self = .double(array)
        case .string:
            var array: [String] = []
            for item in items {
                guard case let .string(value) = item else {
                    throw .notConvertibleToVariant
                }
                array.append(value)
            }
            self = .string(array)
        case .array:
            var array: [Point] = []
            for item in items {
                guard case let .array(pointValues) = item else {
                    throw .notConvertibleToVariant
                }
                guard pointValues.count == 2 else {
                    throw .notConvertibleToVariant
                }
                
                let value: Point
                switch (pointValues[0], pointValues[1]) {
                case let (.int(x), .int(y)):
                    value = Point(Double(x), Double(y))
                case let (.int(x), .float(y)):
                    value = Point(Double(x), y)
                case let (.float(x), .int(y)):
                    value = Point(x, Double(y))
                case let (.float(x), .float(y)):
                    value = Point(x, y)
                default:
                    throw .notConvertibleToVariant
                }

                array.append(value)
            }
            self = .point(array)
        default:
            throw .notConvertibleToVariant
        }
    }
   
    /// Create a new variant array of given type from JSON items.
    ///
    /// The JSON items must match required type as described in the ``Variant/init(type:json:)``.
    /// If any of the items does not match the required type, then `nil` is returned.
    ///
    /// This initialiser is used to decode a JSON-encoded variant tuple.
    ///
    /// - SeeAlso: ``Variant/init(type:json:)``, ``VariantAtom/init(type:json:)``
    ///
    public init?(type: AtomType, jsonItems items: [JSONValue]) {
        switch type {
        case .int:
            var result: [Int] = []
            for item in items {
                guard let value = item.exactInt() else {
                    return nil
                }
                result.append(value)
            }
            self = .int(result)
        case .double:
            var result: [Double] = []
            for item in items {
                guard let value = item.exactDouble() else {
                    return nil
                }
                result.append(value)
            }
            self = .double(result)
        case .bool:
            var result: [Bool] = []
            for item in items {
                guard case let .bool(value) = item else {
                    return nil
                }
                result.append(value)
            }
            self = .bool(result)
        case .string:
            var result: [String] = []
            for item in items {
                guard case let .string(value) = item else {
                    return nil
                }
                result.append(value)
            }
            self = .string(result)
        case .point:
            var result: [Point] = []
            for item in items {
                guard case let .array(components) = item else {
                    return nil
                }
                guard components.count == 2 else {
                    return nil
                }
                guard let x = components[0].exactDouble(), let y = components[1].exactDouble() else {
                    return nil
                }
                result.append(Point(x: x, y: y))
            }
            self = .point(result)
        }
    }
    
    public func asJSON() -> JSONValue {
        switch self {
        case let .int(items): .array(items.map { .int($0) })
        case let .double(items): .array(items.map { .float($0) })
        case let .string(items): .array(items.map { .string($0) })
        case let .bool(items): .array(items.map { .bool($0) })
        case let .point(points):
                .array(points.map {
                    .array([.float($0.x), .float($0.y)])
                })
        }
    }
}


