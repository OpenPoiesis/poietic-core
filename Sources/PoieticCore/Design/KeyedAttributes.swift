//
//  KeyedAttributes.swift
//
//
//  Created by Stefan Urbanek on 17/07/2022.
//
//  Ported from Tarot.

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
    func dictionary(withKeys: [AttributeKey]) -> [AttributeKey:Variant]

    /// Returns an attribute value for given key.
    ///
    func attribute(forKey key: String) -> Variant?
}

extension KeyedAttributes {
    public func dictionary(withKeys: [AttributeKey]) -> [AttributeKey:Variant] {
        let tuples = attributeKeys.compactMap { key in
            self.attribute(forKey: key).map { (key, $0) }
        }
        
        return [AttributeKey:Variant](uniqueKeysWithValues: tuples)
    }
}

/// Protocol for objects where attributes can be modified by using the attribute
/// names.
///
/// This protocol is provided for inspectors and import/export functionality.
///
public protocol MutableKeyedAttributes: KeyedAttributes {
    mutating func setAttribute(value: Variant, forKey key: AttributeKey) throws
    mutating func setAttributes(_ dict: [AttributeKey:Variant]) throws
}

extension MutableKeyedAttributes {
    public mutating func setAttributes(_ dict: [AttributeKey:Variant]) throws {
        for (key, value) in dict {
            try self.setAttribute(value: value, forKey: key)
        }
    }
}
