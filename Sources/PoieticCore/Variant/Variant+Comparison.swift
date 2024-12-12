//
//  Variant+Comparison.swift
//
//  Comparison rules for Variant and its wrapped types VariantAtom and
//  VariantArray
//
//  Created by Stefan Urbanek on 06/03/2024.
//

extension VariantAtom {
    public static func <(lhs: VariantAtom, rhs: VariantAtom) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue < rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) < rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue < Double(rvalue)
        case let (.double(lvalue), .double(rvalue)): lvalue < rvalue
        case let (.string(lvalue), .string(rvalue)): lvalue.lexicographicallyPrecedes(rvalue)
        default: false
        }
    }
    public static func <=(lhs: VariantAtom, rhs: VariantAtom) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue <= rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) <= rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue <= Double(rvalue)
        case let (.double(lvalue), .double(rvalue)): lvalue <= rvalue
        case let (.string(lvalue), .string(rvalue)):
            lvalue == rvalue || lvalue.lexicographicallyPrecedes(rvalue)
        default: false
        }
    }

    public static func >(lhs: VariantAtom, rhs: VariantAtom) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue > rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) > rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue > Double(rvalue)
        case let (.double(lvalue), .double(rvalue)): lvalue > rvalue
        case let (.string(lvalue), .string(rvalue)): rvalue.lexicographicallyPrecedes(lvalue)
        default: false
        }
    }
    public static func >=(lhs: VariantAtom, rhs: VariantAtom) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue >= rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) >= rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue >= Double(rvalue)
        case let (.double(lvalue), .double(rvalue)): lvalue >= rvalue
        case let (.string(lvalue), .string(rvalue)):
            lvalue == rvalue || rvalue.lexicographicallyPrecedes(lvalue)
        default: false
        }
    }

    public static func ==(lhs: VariantAtom, rhs: VariantAtom) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue == rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) == rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue == Double(rvalue)
        case let (.double(lvalue), .double(rvalue)): lvalue == rvalue
        case let (.string(lvalue), .string(rvalue)): lvalue == rvalue
        case let (.bool(lvalue), .bool(rvalue)): lvalue == rvalue
        case let (.point(lvalue), .point(rvalue)): lvalue == rvalue
        default: false
        }
    }

    public static func !=(lhs: VariantAtom, rhs: VariantAtom) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue != rvalue
        case let (.int(lvalue), .double(rvalue)): Double(lvalue) != rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue != Double(rvalue)
        case let (.double(lvalue), .double(rvalue)): lvalue != rvalue
        case let (.string(lvalue), .string(rvalue)): lvalue != rvalue
        case let (.bool(lvalue), .bool(rvalue)): lvalue != rvalue
        case let (.point(lvalue), .point(rvalue)): lvalue != rvalue
        default: true
        }
    }
}
extension VariantArray {
    public static func <(lhs: VariantArray, rhs: VariantArray) throws -> Bool {
        false
    }
    public static func <=(lhs: VariantArray, rhs: VariantArray) throws -> Bool {
        false
    }

    public static func >(lhs: VariantArray, rhs: VariantArray) throws -> Bool {
        false
    }
    public static func >=(lhs: VariantArray, rhs: VariantArray) throws -> Bool {
        false
    }
    public static func ==(lhs: VariantArray, rhs: VariantArray) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue == rvalue
        case let (.int(lvalue), .double(rvalue)): lvalue.map {Double($0)} == rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue == rvalue.map {Double($0)}
        case let (.double(lvalue), .double(rvalue)): lvalue == rvalue
        case let (.string(lvalue), .string(rvalue)): lvalue == rvalue
        case let (.bool(lvalue), .bool(rvalue)): lvalue == rvalue
        case let (.point(lvalue), .point(rvalue)): lvalue == rvalue
        default: false
        }
    }

    public static func !=(lhs: VariantArray, rhs: VariantArray) -> Bool {
        switch (lhs, rhs) {
        case let (.int(lvalue), .int(rvalue)): lvalue != rvalue
        case let (.int(lvalue), .double(rvalue)): lvalue.map {Double($0)} != rvalue
        case let (.double(lvalue), .int(rvalue)): lvalue == rvalue.map {Double($0)}
        case let (.double(lvalue), .double(rvalue)): lvalue != rvalue
        case let (.string(lvalue), .string(rvalue)): lvalue != rvalue
        case let (.bool(lvalue), .bool(rvalue)): lvalue != rvalue
        case let (.point(lvalue), .point(rvalue)): lvalue != rvalue
        default: true
        }
    }
}

extension Variant {
    public static func <(lhs: Variant, rhs: Variant) -> Bool {
        switch (lhs, rhs) {
        case let (.atom(lvalue), .atom(rvalue)): lvalue < rvalue
        default: false
        }
    }
    public static func <=(lhs: Variant, rhs: Variant) -> Bool {
        switch (lhs, rhs) {
        case let (.atom(lvalue), .atom(rvalue)): lvalue <= rvalue
        default: false
        }
    }

    public static func >(lhs: Variant, rhs: Variant) -> Bool {
        switch (lhs, rhs) {
        case let (.atom(lvalue), .atom(rvalue)): lvalue > rvalue
        default: false
        }
    }
    public static func >=(lhs: Variant, rhs: Variant) -> Bool {
        switch (lhs, rhs) {
        case let (.atom(lvalue), .atom(rvalue)): lvalue >= rvalue
        default: false
        }
    }
    public static func ==(lhs: Variant, rhs: Variant) -> Bool {
        switch (lhs, rhs) {
        case let (.array(lvalue), .array(rvalue)): lvalue == rvalue
        case (.array(_), .atom(_)): false
        case (.atom(_), .array(_)): false
        case let (.atom(lvalue), .atom(rvalue)): lvalue == rvalue
        }
    }

    public static func !=(lhs: Variant, rhs: Variant) -> Bool {
        switch (lhs, rhs) {
        case let (.array(lvalue), .array(rvalue)): lvalue != rvalue
        case (.array(_), .atom(_)): false
        case (.atom(_), .array(_)): false
        case let (.atom(lvalue), .atom(rvalue)): lvalue != rvalue
        }
    }
}
