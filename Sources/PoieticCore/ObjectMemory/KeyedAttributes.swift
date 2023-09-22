//
//  KeyedAttributes.swift
//
//
//  Created by Stefan Urbanek on 17/07/2022.
//
//  Ported from Tarot.

public enum AttributeError: Error {
    /// Raised when reading or setting an attribute of a type that is not
    /// convertible to the required value.
    ///
    case typeMismatch(ForeignValue, AtomType)
    
    /// Raised when a non-nil value was expected.
    case unexpectedNil
    
    /// Raised when an attribute is expected.
    case unknownAttribute(name: String, type: String)
}

/// Type for object attribute key.
public typealias AttributeKey = String

/// A protocol for objects that provide their attributes by keys.
///
public protocol KeyedAttributes {
    /// List of attributes that the object provides.
    ///
    var attributeKeys: [AttributeKey] { get }
    
    /// Returns a dictionary of attributes.
    ///
    func dictionary(withKeys: [AttributeKey]) -> [AttributeKey:ForeignValue]

    /// Returns an attribute value for given key.
    ///
    func attribute(forKey key: String) -> ForeignValue?
}

extension KeyedAttributes {
    public func dictionary(withKeys: [AttributeKey]) -> [AttributeKey:ForeignValue] {
        let tuples = attributeKeys.compactMap { key in
            self.attribute(forKey: key).map { (key, $0) }
        }
        
        return [AttributeKey:ForeignValue](uniqueKeysWithValues: tuples)
    }
}

/// Protocol for objects where attributes can be modified by using the attribute
/// names.
///
/// This protocol is provided for inspectors and import/export functionality.
///
public protocol MutableKeyedAttributes: KeyedAttributes {
    mutating func setAttribute(value: ForeignValue, forKey key: AttributeKey) throws
    mutating func setAttributes(_ dict: [AttributeKey:ForeignValue]) throws
}

extension MutableKeyedAttributes {
    public mutating func setAttributes(_ dict: [AttributeKey:ForeignValue]) throws {
        for (key, value) in dict {
            try self.setAttribute(value: value, forKey: key)
        }
    }
}
