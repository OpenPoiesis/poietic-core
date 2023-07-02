//
//  ForeignRecord.swift
//  
//
//  Created by Stefan Urbanek on 06/10/2022.
//


public enum ForeignRecordError: Error {
    case unknownKey(String)
    case typeMismatch(String, String)
}

public struct ForeignCodingKey: CodingKey, CustomStringConvertible {
    public let stringValue: String
    
    public init?(intValue: Int) {
        self.stringValue = String(intValue)
    }
    public init(stringValue: String) {
        self.stringValue = stringValue
    }
    public var intValue: Int? { return Int(stringValue)}
    
    public var description: String { stringValue }
}

extension ForeignRecord: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ForeignCodingKey.self)
        var dict: [String:ForeignValue] = [:]
        for key in container.allKeys {
            let value = try container.decode(ForeignValue.self, forKey: key)
            dict[key.stringValue] = value
        }
        self.dict = dict
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ForeignCodingKey.self)

        for (key, value) in dict {
            let codingKey = ForeignCodingKey(stringValue: key)
            try container.encode(value, forKey: codingKey)
        }
    }
}
/// A collection of key-value pairs that store data used for exchange with
/// external environment such as database.
///
public struct ForeignRecord {
    let dict: [String:ForeignValue]
    
    public init(_ dictionary: [String:ForeignValue]) {
        self.dict = dictionary
    }
    
    public init(_ dictionary: [String:any ValueProtocol]) {
        var dict: [String:ForeignValue] = [:]

        for (key, value) in dictionary {
            switch value.valueType {
            case .int:
                dict[key] = ForeignValue(value.intValue()!)
            case .bool:
                dict[key] = ForeignValue(value.boolValue()!)
            case .double:
                dict[key] = ForeignValue(value.doubleValue()!)
            case .string:
                dict[key] = ForeignValue(value.stringValue()!)
            case .point:
                // FIXME: Support point
                fatalError("Point is not supported")
            }
        }
        self.dict = dict
    }
    
    public subscript(key: String) -> ForeignValue? {
        return dict[key]
    }
    
    public var allKeys: [String] {
        return Array(dict.keys)
    }
    
    public func boolValue(for key: String) throws -> Bool {
        guard let value = try boolValueIfPresent(for: key) else {
            throw ForeignRecordError.unknownKey(key)
        }
        return value
    }
    public func intValue(for key: String) throws -> Int {
        guard let value = try intValueIfPresent(for: key) else {
            throw ForeignRecordError.unknownKey(key)
        }
        return value
    }
    public func doubleValue(for key: String) throws -> Double {
        guard let value = try doubleValueIfPresent(for: key) else {
            throw ForeignRecordError.unknownKey(key)
        }
        return value
    }
    public func stringValue(for key: String) throws -> String {
        guard let value = try stringValueIfPresent(for: key) else {
            throw ForeignRecordError.unknownKey(key)
        }
        return value
    }
    public func IDValue(for key: String) throws -> UInt64 {
        guard let value = try IDValueIfPresent(for: key) else {
            throw ForeignRecordError.unknownKey(key)
        }
        return value
    }
    
    public func boolValueIfPresent(for key: String) throws -> Bool? {
        guard let existingValue = dict[key] else {
            return nil
        }
        let value = try existingValue.boolValue()
        return value
    }
    
    public func intValueIfPresent(for key: String) throws -> Int? {
        guard let existingValue = dict[key] else {
            return nil
        }
        let value = try existingValue.intValue()
        return value
    }
    
    public func doubleValueIfPresent(for key: String) throws -> Double? {
        guard let existingValue = dict[key] else {
            return nil
        }
        let value = try existingValue.doubleValue()
        return value
    }
    
    public func stringValueIfPresent(for key: String) throws -> String? {
        guard let existingValue = dict[key] else {
            return nil
        }
        let value = try existingValue.stringValue()
        return value
    }
    
    public func IDValueIfPresent(for key: String) throws -> UInt64? {
        guard let existingValue = dict[key] else {
            return nil
        }
        let value = try existingValue.idValue()
        return value
    }
}

extension ForeignRecord: Equatable {
    public static func == (lhs: ForeignRecord, rhs: ForeignRecord) -> Bool {
        guard lhs.allKeys == rhs.allKeys else {
            return false
        }

        for key in lhs.allKeys {
            guard let lvalue = lhs.dict[key],
                  let rvalue = rhs.dict[key] else {
                return false
            }
            if lvalue != rvalue {
                return false
            }
        }
        return true
    }
    
    
}

/// A foreign record that has a mapping of other foreign records associated
/// with it.
///
/// The extended foreign record is used to represent snapshots and their
/// components and is used when storing the snapshots in a JSON representation.
///
/// - Warning: This structure and whole concept of foreign records is likely
///            to change. Consider this as a technical debt of the library
///            created during prototyping.
///
public struct ExtendedForeignRecord {
    public let main: ForeignRecord
    public let components: [String:ForeignRecord]
    
    /// Creates a new foreign record.
    ///
    init(main: ForeignRecord, components: [String: ForeignRecord]) {
        precondition(!main.allKeys.contains("components"),
                     "The main record of the extended foreign record must not contain a key `components`")
        
        self.main = main
        self.components = components
    }
}


extension ExtendedForeignRecord: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ForeignCodingKey.self)
        let subContainer = try container.nestedContainer(keyedBy: ForeignCodingKey.self,
                                                     forKey: ForeignCodingKey(stringValue: "components"))
        var dict: [String:ForeignValue] = [:]
        for key in container.allKeys {
            if key.stringValue == "components" {
                continue
            }
            
            let record = try container.decode(ForeignValue.self, forKey: key)
            dict[key.stringValue] = record
        }
        main = ForeignRecord(dict)

        var components: [String:ForeignRecord] = [:]
        
        for key in subContainer.allKeys {
            let component = try subContainer.decode(ForeignRecord.self,
                                                    forKey: key)
            components[key.stringValue] = component
        }
        
        self.components = components

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ForeignCodingKey.self)

        for (key, value) in main.dict {
            let codingKey = ForeignCodingKey(stringValue: key)
            try container.encode(value, forKey: codingKey)
        }
  
        let codingKey = ForeignCodingKey(stringValue: "components")
        try container.encode(components, forKey: codingKey)
    }
}
