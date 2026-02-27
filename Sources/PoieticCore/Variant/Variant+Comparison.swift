//
//  Variant+Comparison.swift
//
//  Comparison rules for Variant and its wrapped types VariantAtom and
//  VariantArray
//
//  Created by Stefan Urbanek on 06/03/2024.
//

extension VariantAtom {
    /// Compares two variant atoms.
    ///
    /// Rules:
    /// - Two ints are compared as they are
    /// - Two doubles are compared as they are
    /// - When comparing int and double, int is casted to double and compared as doubles.
    /// - Two strings are compared lexicographically.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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
    /// Compares two variant atoms.
    ///
    /// Rules:
    /// - Two ints are compared as they are
    /// - Two doubles are compared as they are
    /// - When comparing int and double, int is casted to double and compared as doubles.
    /// - Two strings are compared lexicographically.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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
    
    /// Compares two variant atoms.
    ///
    /// Rules:
    /// - Two ints are compared as they are
    /// - Two doubles are compared as they are
    /// - When comparing int and double, int is casted to double and compared as doubles.
    /// - Two strings are compared lexicographically.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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
    /// Compares two variant atoms.
    ///
    /// Rules:
    /// - Two ints are compared as they are
    /// - Two doubles are compared as they are
    /// - When comparing int and double, int is casted to double and compared as doubles.
    /// - Two strings are compared lexicographically.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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
}

extension VariantAtom {
    /// Compares two variant atoms for equality.
    ///
    /// Rules:
    /// - If both are of the same, they are compared as they are.
    /// - An int and an double are compared by casting the int to double and then comparing doubles.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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

    /// Compares two variant atoms for equality.
    ///
    /// Rules:
    /// - If both are of the same, they are compared as they are.
    /// - An int and an double are compared by casting the int to double and then comparing doubles.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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
    /// Compares two variant arrays for equality.
    ///
    /// Rules:
    /// - If both are of the same type, they are compared as they are.
    /// - If one is array of ints and other of double, the ints are cast to doubles and the arrays
    ///   are compared as arrays of doubles.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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

    /// Compares two variant arrays for equality.
    ///
    /// Rules:
    /// - If both are of the same type, they are compared as they are.
    /// - If one is array of ints and other of double, the ints are cast to doubles and the arrays
    ///   are compared as arrays of doubles.
    /// - Other type combinations are not considered comparable (string is not cast to a number,
    ///   neither int to a bool or vice versa)
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
