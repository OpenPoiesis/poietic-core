//
//  ConstraintErrors.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 26/09/2024.
//

/// Type error detail produced when checking object types against a metamodel.
///
/// - SeeAlso: ``ObjectSnapshot/check(conformsTo:)``
///
public enum ObjectTypeError: Error, Equatable, CustomStringConvertible {
    /// Object type is not known in the metamodel.
    case unknownType(String)

    /// Object is missing a required attribute from a trait.
    case missingTraitAttribute(Attribute, String)
    
    /// Value for an attribute is not convertible to a required type as
    /// specified in the trait owning the attribute.
    /// 
    case typeMismatch(Attribute, ValueType)
    
    public var description: String {
        switch self {
        case let .unknownType(name):
            "Unknown object type: \(name)"
        case let .missingTraitAttribute(attribute, trait):
            "Missing attribute '\(attribute.name)' required by trait '\(trait)'"
        case let .typeMismatch(attribute, actualType):
            "Type mismatch of Attribute '\(attribute.name)', \(actualType) is not convertible to \(attribute.type)"
        }
    }
}


/// Collection of object type violation errors produced when checking object
/// types.
///
/// - SeeAlso: ``ObjectSnapshot/check(conformsTo:)``
///
public struct ObjectConstraintError: Error {
    public let underlyingErrors: [ObjectTypeError]
    
    public init(underlyingErrors: [ObjectTypeError]) {
        self.underlyingErrors = underlyingErrors
    }
}

/// Error generated when a frame is checked for constraints and object types.
///
/// This error is produced by the ``ConstraintChecker/check(_:)``.
///
public struct FrameConstraintError: Error {
    /// List of constraint violations.
    ///
    public let violations: [ConstraintViolation]
    
    /// List of object type errors.
    ///
    public let objectErrors: [ObjectID: [ObjectTypeError]]
    
    /// Create a new constraint validation error.
    ///
    public init(violations: [ConstraintViolation],
                objectErrors: [ObjectID:[ObjectTypeError]]) {
        self.violations = violations
        self.objectErrors = objectErrors
    }
}

