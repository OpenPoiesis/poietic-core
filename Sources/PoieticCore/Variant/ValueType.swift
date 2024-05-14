//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 14/05/2024.
//

public enum ValueType: Equatable, CustomStringConvertible {
    case atom(AtomType)
    case array(AtomType)
    
    public static let bool    = atom(.bool)
    public static let int     = atom(.int)
    public static let double  = atom(.double)
    public static let string  = atom(.string)
    public static let point   = atom(.point)
    
    // TODO: Rename to `arrayOfXXX`
    public static let bools   = array(.bool)
    public static let ints    = array(.int)
    public static let doubles = array(.double)
    public static let strings = array(.string)
    public static let points  = array(.point)

    public var isAtom: Bool {
        switch self {
        case .atom: true
        case .array: false
        }
    }

    public var isArray: Bool {
        switch self {
        case .atom: false
        case .array: true
        }
    }
    
    public func isConvertible(to other: ValueType) -> Bool {
        switch (self, other) {
        case (.atom(let lhs), .atom(let rhs)):
            lhs.isConvertible(to: rhs)
        case (.atom(_), .array(_)):
            // TODO: Point?
            false
        case (.array(_), .atom(_)):
            // TODO: Point?
            false
        case (.array(let lhs), .array(let rhs)):
            lhs.isConvertible(to: rhs)
        }
    }
    
    public func isConvertible(to other: VariableType) -> Bool {
        switch other {
        case .any: true
        case .concrete(let otherType): isConvertible(to: otherType)
        case .union(let types): types.contains { isConvertible(to: $0) }
        }
    }

    public var description: String {
        switch self {
        case .atom(let value): "\(value)"
        case .array(let value): "array<\(value)>"
        }
    }
}


/// Type of a function argument.
///
public enum VariableType: Equatable {
    /// Function argument can be of any type.
    case any
    
    /// Function argument must be of only one concrete type.
    case concrete(ValueType)
    
    /// Function argument can be of one of the specified types.
    case union([ValueType])
    
    public static let int = VariableType.concrete(.int)
    public static let ints = VariableType.concrete(.ints)
    public static let double = VariableType.concrete(.double)
    public static let doubles = VariableType.concrete(.doubles)
    public static let bool = VariableType.concrete(.bool)
    public static let bools = VariableType.concrete(.bools)
    public static let string = VariableType.concrete(.string)
    public static let strings = VariableType.concrete(.strings)
    public static let point = VariableType.concrete(.point)
    public static let points = VariableType.concrete(.points)
    public static let numeric = VariableType.union([.int, .double])
    public static let objectReference = VariableType.union([.int, .string])
    
    /// Function that verifies whether the given type matches the type
    /// described by this object.
    ///
    /// - Returns: `true` if the type matches.
    ///
    public func matches(_ type: ValueType) -> Bool {
        switch self {
        case .any: true
        case .concrete(let concrete): type == concrete
        case .union(let types): types.contains(type)
        }
    }
    
    /// Flag whether the variable is a concrete array type.
    ///
    public var isArray: Bool {
        switch self {
        case .any: false
        case .concrete(let type): type.isArray
        case .union: false
        }
    }
    
    public func isConvertible(to other: VariableType) -> Bool {
        switch (self, other) {
        case (.any, .any):
            true
        case (.any, .concrete(_)):
            false // need to cast
        case (.any, .union(_)):
            false // need to cast
        case (.concrete(_), .any):
            true
        case (.concrete(let lhs), .concrete(let rhs)):
            lhs.isConvertible(to: rhs)
        case (.concrete(let lhs), .union(let rhs)):
            rhs.contains {lhs.isConvertible(to: $0) }
        case (.union(_), .any):
            true
        case (.union(let lhs), .concrete(let rhs)):
            lhs.contains {$0.isConvertible(to: rhs) }
        case (.union(let lhs), .union(let rhs)):
            lhs.contains { ltype in
                rhs.contains { rtype in
                    ltype.isConvertible(to: rtype)
                }
            }
        }
    }

}

