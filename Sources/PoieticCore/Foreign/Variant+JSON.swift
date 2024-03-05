//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

// TODO: [REFACTORING] consolidate this error with some other error
public enum ForeignValueError: Error {
    // TODO: Is this used?
    case unknownForeignType
    case invalidType
    case invalidPointValue
    case arrayMustHaveSameItemType
    case invalidArrayItem
    case expectedDictionary
    /// When attributes in foreign record are not a dictionary or other expected structure
    case invalidAttributesStructure
}

extension Variant {
    // TODO: Make it into init()
    public static func fromJSON(_ json: JSONValue, path: [String] = []) throws -> Variant {
        switch json {
        case let .int(value):
            return Variant(value)
        case let .bool(value):
            return Variant(value)
        case let .string(value):
            return Variant(value)
        case let .double(value):
            return Variant(value)
        case let .array(items):
            return try .array(VariantArray.fromJSONItems(items))
        default:
            throw ForeignValueError.invalidType
        }
    }
    
    /// Create a Foundation-compatible JSON object representation.
    ///
    public func asJSON() -> JSONValue {
        switch self {
        case let .atom(atom):  atom.asJSON()
        case let .array(array): array.asJSON()
        }
    }
}


extension VariantAtom {
    // TODO: Make it into init()
    public static func fromJSON(_ json: JSONValue, path: [String] = []) throws -> VariantAtom {
        switch json {
        case let .int(value):
            return .int(value)
        case let .bool(value):
            return .bool(value)
        case let .string(value):
            return .string(value)
        case let .double(value):
            return .double(value)
        case let .array(items):
            guard items.count == 2 else {
                throw ForeignValueError.invalidType
            }
            switch (items[0], items[1]) {
            case let (.int(x), .int(y)): return .point(Point(Double(x), Double(y)))
            case let (.int(x), .double(y)): return .point(Point(Double(x), y))
            case let (.double(x), .int(y)): return .point(Point(x, Double(y)))
            case let (.double(x), .double(y)): return .point(Point(x, y))
            default:
                throw ForeignValueError.invalidPointValue
            }
        default:
            throw ForeignValueError.invalidType

        }
    }
    
    public func asJSON() -> JSONValue {
        switch self {
        case let .int(value): .int(value)
        case let .double(value): .double(value)
        case let .string(value): .string(value)
        case let .bool(value): .bool(value)
        case let .point(point): .array([.double(point.x), .double(point.y)])
        }
    }
}

extension VariantArray {
    // TODO: Make it into init()
    public static func fromJSONItems(_ items: [JSONValue], path: [String] = []) throws -> VariantArray {
        if items.count == 0 {
            // TODO: Have empty array variant?
            // We default to a string array, as it is the most to-value convertible
            return .string([])
        }

        let first = items[0]

        switch first {
        case .bool:
            var array: [Bool] = []
            for item in items {
                guard case let .bool(value) = item else {
                    throw ForeignValueError.arrayMustHaveSameItemType
                }
                array.append(value)
            }
            return .bool(array)
        case .int:
            var array: [Int] = []
            for item in items {
                guard case let .int(value) = item else {
                    throw ForeignValueError.arrayMustHaveSameItemType
                }
                array.append(value)
            }
            return .int(array)
        case .double:
            var array: [Double] = []
            for item in items {
                guard case let .double(value) = item else {
                    throw ForeignValueError.arrayMustHaveSameItemType
                }
                array.append(value)
            }
            return .double(array)
        case .string:
            var array: [String] = []
            for item in items {
                guard case let .string(value) = item else {
                    throw ForeignValueError.arrayMustHaveSameItemType
                }
                array.append(value)
            }
            return .string(array)
        case .array:
            var array: [Point] = []
            for item in items {
                guard case let .array(pointValues) = item else {
                    throw ForeignValueError.arrayMustHaveSameItemType
                }
                guard pointValues.count == 2 else {
                    throw ForeignValueError.invalidPointValue
                }
                let value: Point
                switch (pointValues[0], pointValues[1]) {
                case let (.int(x), .int(y)): value = Point(Double(x), Double(y))
                case let (.int(x), .double(y)): value = Point(Double(x), y)
                case let (.double(x), .int(y)): value = Point(x, Double(y))
                case let (.double(x), .double(y)): value = Point(x, y)
                default:
                    throw ForeignValueError.invalidPointValue
                }

                array.append(value)
            }
            return .point(array)
        default:
            throw ForeignValueError.invalidArrayItem
        }
    }
    public func asJSON() -> JSONValue {
        switch self {
        case let .int(items): .array(items.map { .int($0) })
        case let .double(items): .array(items.map { .double($0) })
        case let .string(items): .array(items.map { .string($0) })
        case let .bool(items): .array(items.map { .bool($0) })
        case let .point(points):
                .array(points.map {
                    .array([.double($0.x), .double($0.y)])
                })
        }
    }
}


extension ForeignRecord {
    public init(_ dictionary: [String:JSONValue]) throws {
        self.dict = [:]
        for (key, jsonValue) in dictionary {
            dict[key] = try Variant.fromJSON(jsonValue)
        }
    }

    /// Create a Foundation-compatible JSON object representation.
    ///
    public func asJSON() -> JSONValue {
        let object = dict.mapValues { $0.asJSON() }
        return .object(object)
    }
}
