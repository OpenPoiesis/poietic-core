//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 2020/12/14.
//

public enum ValueError: Error, CustomStringConvertible{
    case typeMismatch(String, String)
    case invalidBooleanValue(String)
    
    public var description: String {
        switch self {
        case .typeMismatch(let given, let expected): "\(given) is not convertible to a \(expected) type."
        case .invalidBooleanValue(let value): "Value '\(value)' is not a valid boolean value."
        }
    }
}

public enum ForeignScalar: Equatable, CustomStringConvertible {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case id(ObjectID)

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
        }
    }
    
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
        }
    }
    
    public func stringValue() -> String {
        switch self {
        case let .int(value): return String(value)
        case let .double(value): return String(value)
        case let .string(value): return String(value)
        case let .bool(value): return String(value)
        case let .id(value): return String(value)
        }
    }

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
        }
    }
    
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
        }
    }
    
    public var description: String {
        stringValue()
    }
}

extension ForeignScalar: Codable {
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
        }
        
        do {
            let value: Bool = try container.decode(Bool.self)
            self = .bool(value)
            return
        }
        catch is DecodingError {
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
        }
    }

}

public enum ForeignValue: Equatable, CustomStringConvertible {
    case scalar(ForeignScalar)
    case array([ForeignScalar])

    public init(_ value: Int) {
        self = .scalar(.int(value))
    }
    public init(_ value: Double) {
        self = .scalar(.double(value))
    }
    public init(_ value: Bool) {
        self = .scalar(.bool(value))
    }
    public init(_ value: String) {
        self = .scalar(.string(value))
    }

    public init(_ id: ObjectID) {
        self = .scalar(.id(id))
    }
    
    public init(ids: [ObjectID]) {
        self = .array(ids.map { ForeignScalar.id($0)} )
    }

    public func intValue() throws -> Int {
        switch self {
        case .scalar(let value): return try value.intValue()
        case .array: throw ValueError.typeMismatch("Array", "int")
        }
    }
    public func stringValue() throws -> String {
        switch self {
        case .scalar(let value): return try value.stringValue()
        case .array: throw ValueError.typeMismatch("Array", "string")
        }
    }
    public func boolValue() throws -> Bool {
        switch self {
        case .scalar(let value): return try value.boolValue()
        case .array: throw ValueError.typeMismatch("Array", "bool")
        }
    }
    public func doubleValue() throws -> Double {
        switch self {
        case .scalar(let value): return try value.doubleValue()
        case .array: throw ValueError.typeMismatch("Array", "double")
        }
    }
    public func idValue() throws -> ObjectID {
        switch self {
        case .scalar(let value): return try value.idValue()
        case .array: throw ValueError.typeMismatch("Array", "ID")
        }
    }
    
    public var description: String {
        switch self {
        case .scalar(let value):
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
            let value: ForeignScalar = try container.decode(ForeignScalar.self)
            self = .scalar(value)
            return
        }
        catch is DecodingError {
            // We are fine, let us try another one.
        }
        do {
            let values: [Int] = try container.decode(Array<Int>.self)
            self = .array(values.map { .int($0) })
            return
        }
        catch is DecodingError {
        }

        // We are not catching error of the last one and let it go through.
        
        let values: [String] = try container.decode(Array<String>.self)
        self = .array(values.map { .string($0) })
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .scalar(let scalar): try container.encode(scalar)
        case .array(let array): try container.encode(array)
        }
    }
}

extension ForeignValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .scalar(.int(value))
    }
    
    public typealias IntegerLiteralType = Int
}

extension ForeignValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .scalar(.string(value))
    }
}
