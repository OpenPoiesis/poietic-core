//
//  StateVector.swift
//  
//
//  Created by Stefan Urbanek on 30/07/2022.
//

import PoieticCore

/// A simple vector-like structure to hold an unordered collection of numeric
/// values that can be accessed by key. Simple arithmetic operations can be done
/// with the structure, such as addition, subtraction and multiplication
/// by a scalar value.
///
///
public struct KeyedNumericVector<Key:Hashable> {
    var items: [Key:Double] = [:]
    
    public var keys: [Key] { return Array(items.keys) }
    public var values: [Double] { return Array(items.values) }

    public init(_ items: [Key:Double] = [:]) {
        self.items = items
    }
    
    public subscript(key: Key) -> Double? {
        get {
            items[key]
        }
        set(value) {
            items[key] = value
        }
    }
    
    public static func *(lhs: Double, rhs: KeyedNumericVector) -> KeyedNumericVector {
        return KeyedNumericVector(rhs.items.mapValues { lhs * $0 })
    }
    public static func *(lhs: KeyedNumericVector, rhs: Double) -> KeyedNumericVector {
        return KeyedNumericVector(lhs.items.mapValues { rhs * $0 })
    }
    public static func /(lhs: KeyedNumericVector, rhs: Double) -> KeyedNumericVector {
        return KeyedNumericVector(lhs.items.mapValues { rhs / $0 })
    }

}


extension KeyedNumericVector: AdditiveArithmetic {
    public static func - (lhs: KeyedNumericVector<Key>, rhs: KeyedNumericVector<Key>) -> KeyedNumericVector<Key> {
        let result = lhs.items.merging(rhs.items) {
            (lvalue, rvalue) in lvalue - rvalue
        }
        return KeyedNumericVector(result)
    }
    
    public static func + (lhs: KeyedNumericVector<Key>, rhs: KeyedNumericVector<Key>) -> KeyedNumericVector<Key> {
        let result = lhs.items.merging(rhs.items) {
            (lvalue, rvalue) in lvalue + rvalue
        }
        return KeyedNumericVector(result)
    }
    
    public static var zero: KeyedNumericVector<Key> {
        return KeyedNumericVector<Key>()
    }
}

public typealias StateVector = KeyedNumericVector<ObjectID>
