//
//  ForeignRecord.swift
//  
//
//  Created by Stefan Urbanek on 06/10/2022.
//


/// An error thrown when there is an issue with retrieving or converting
/// a foreign value.
///
public enum ForeignRecordError: Error {
    
    /// Error caused by trying to get an unknown attribute from a foreign
    /// record.
    ///
    /// - SeeAlso: ``ForeignRecord``
    ///
    case unknownKey(String)
    
    /// Error caused when trying to convert a foreign value to a type
    /// that the value can not be converted. For example, trying to get
    /// an integer value from a foreign string value `"moon"`.
    ///
    case valueError(String, ValueError)
}

struct ForeignCodingKey: CodingKey, CustomStringConvertible {
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

// Currently used only for server.
extension ForeignRecord: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ForeignCodingKey.self)
        var dict: [String:Variant] = [:]
        for key in container.allKeys {
            let value = try container.decode(Variant.self, forKey: key)
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
    var dict: [String:Variant]
    
    public var dictionary: [String:Variant] { dict }

    public init() {
        self.dict = [:]
    }
    /// Create a foreign record from a dictionary.
    ///
    /// Keys are attribute names and values are foreign values of the attribute.
    ///
    public init(_ dictionary: [String:Variant]) {
        self.dict = dictionary
    }
    
    /// Get a value for a key, if is present in the record. Otherwise
    /// returns `nil`.
    ///
    public subscript(key: String) -> Variant? {
        get {
            dict[key]
        }
        set(value) {
            dict[key] = value
        }
    }
   
    /// Returns `true` if the foreign record contains the given key.
    /// 
    public func contains(_ key: String) -> Bool {
        return dict[key] != nil
    }
    /// Return list of all keys of the record.
    ///
    public var allKeys: [String] {
        return Array(dict.keys)
    }
    
    /// Try to get a boolean value from the foreign value.
    ///
    /// - Throws: ``ForeignRecordError/unknownKey(_:)`` if the record
    ///    does not have a value for given key.
    public func boolValue(for key: String) throws (ForeignRecordError) -> Bool {
        guard let value = try boolValueIfPresent(for: key) else {
            throw .unknownKey(key)
        }
        return value
    }

    /// Try to get a integer value from the foreign value.
    ///
    /// - Throws: ``ForeignRecordError/unknownKey(_:)`` if the record
    ///    does not have a value for given key.
    public func intValue(for key: String) throws (ForeignRecordError) -> Int {
        guard let value = try intValueIfPresent(for: key) else {
            throw .unknownKey(key)
        }
        return value
    }

    /// Try to get a double value from the foreign value.
    ///
    /// - Throws: ``ForeignRecordError/unknownKey(_:)`` if the record
    ///    does not have a value for given key.
    public func doubleValue(for key: String) throws (ForeignRecordError) -> Double {
        guard let value = try doubleValueIfPresent(for: key) else {
            throw .unknownKey(key)
        }
        return value
    }

    /// Try to get a string value from the foreign value.
    ///
    /// - Throws: ``ForeignRecordError/unknownKey(_:)`` if the record
    ///    does not have a value for given key.
    public func stringValue(for key: String) throws (ForeignRecordError) -> String {
        guard let value = try stringValueIfPresent(for: key) else {
            throw .unknownKey(key)
        }
        return value
    }

    /// Try to get an object ID value from the foreign value.
    ///
    /// - Throws: ``ForeignRecordError/unknownKey(_:)`` if the record
    ///    does not have a value for given key.
    public func IDValue(for key: String) throws (ForeignRecordError) -> UInt64 {
        guard let value = try IDValueIfPresent(for: key) else {
            throw .unknownKey(key)
        }
        return value
    }
    
    /// Try to get a bool value from the foreign value, if the record
    /// has the key. If not then `nil` is returned.
    ///
    /// - Throws: ``ForeignRecordError/valueError(_:_:)`` if the value
    ///   can not be converted to bool.
    ///
    public func boolValueIfPresent(for key: String) throws (ForeignRecordError) -> Bool? {
        guard let existingValue = dict[key] else {
            return nil
        }
        do {
            return try existingValue.boolValue()
        }
        catch {
            throw .valueError(key, error)
        }
    }
    

    /// Try to get an integer value from the foreign value, if the record
    /// has the key. If not then `nil` is returned.
    ///
    /// - Throws: ``ForeignRecordError/valueError(_:_:)`` if the value
    ///   can not be converted to integer.
    ///
    public func intValueIfPresent(for key: String) throws (ForeignRecordError) -> Int? {
        guard let existingValue = dict[key] else {
            return nil
        }
        do {
            return try existingValue.intValue()
        }
        catch {
            throw .valueError(key, error)
        }
    }
    
    /// Try to get a double value from the foreign value, if the record
    /// has the key. If not then `nil` is returned.
    ///
    /// - Throws: ``ForeignRecordError/valueError(_:_:)`` if the value
    ///   can not be converted to double.
    ///
    public func doubleValueIfPresent(for key: String) throws (ForeignRecordError) -> Double? {
        guard let existingValue = dict[key] else {
            return nil
        }
        do {
            return try existingValue.doubleValue()
        }
        catch {
            throw .valueError(key, error)
        }
    }
    
    /// Try to get a string value from the foreign value, if the record
    /// has the key. If not then `nil` is returned.
    ///
    /// - Throws: ``ForeignRecordError/valueError(_:_:)`` if the value
    ///   can not be converted to string (like an array).
    ///
    public func stringValueIfPresent(for key: String) throws (ForeignRecordError) -> String? {
        guard let existingValue = dict[key] else {
            return nil
        }
        do {
            return try existingValue.stringValue()
        }
        catch {
            throw .valueError(key, error)
        }
    }
    
    /// Try to get an object ID value from the foreign value, if the record
    /// has the key. If not then `nil` is returned.
    ///
    /// - Throws: ``ForeignRecordError/valueError(_:_:)`` if the value
    ///   can not be converted to ID.
    ///
    public func IDValueIfPresent(for key: String) throws (ForeignRecordError) -> UInt64? {
        guard let existingValue = dict[key] else {
            return nil
        }
        let stringValue: String
        do {
            stringValue = try existingValue.stringValue()
        }
        catch {
            throw .valueError(key, error)
        }

        if let value = ObjectID(stringValue) {
            return value
        }
        else {
            throw .valueError(key, .conversionToIDFailed(.string))
        }
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

extension ForeignRecord: Sequence {
    public typealias Iterator = [String:Variant].Iterator
    public func makeIterator() -> Self.Iterator {
        return self.dict.makeIterator()
    }
}

