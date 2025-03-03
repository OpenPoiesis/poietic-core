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
public enum ObjectTypeError: Error, Equatable, CustomStringConvertible, DesignIssueConvertible {
    
    /// Object type is not known in the metamodel.
    case unknownType(String)

    /// Object is missing a required attribute from a trait.
    case missingTraitAttribute(Attribute, String)
    
    /// Value for an attribute is not convertible to a required type as
    /// specified in the trait owning the attribute.
    /// 
    /// - SeeAlso: ``ObjectSnapshot/check(conformsTo:)``,
    ///     ``Variant/isConvertible(to:)``, ``Variant/isRepresentable(as:)``
    ///     
    case typeMismatch(Attribute, ValueType)
    
    public var description: String {
        switch self {
        case let .unknownType(name):
            "Unknown object type: \(name)"
        case let .missingTraitAttribute(attribute, trait):
            "Missing attribute '\(attribute.name)' required by trait '\(trait)'"
        case let .typeMismatch(attribute, actualType):
            "Type mismatch of attribute '\(attribute.name)', \(actualType) is not convertible to \(attribute.type)"
        }
    }
    
    public func asDesignIssue() -> DesignIssue {
        switch self {
            
        case let .missingTraitAttribute(attribute, trait):
            DesignIssue(domain: .validation,
                        severity: .error,
                        identifier: "missing_trait_attribute",
                        message: description,
                        hint: nil,
                        details: [
                            "attribute": Variant(attribute.name),
                            "trait": Variant(trait)
                        ])
        case let .typeMismatch(attribute, _):
            DesignIssue(domain: .validation,
                        severity: .error,
                        identifier: "attribute_type_mismatch",
                        message: description,
                        hint: nil,
                        details: [
                            "attribute": Variant(attribute.name),
                            "expected_type": Variant(attribute.type.description)
                        ])
        case let .unknownType(type):
            DesignIssue(domain: .validation,
                        severity: .fatal,
                        identifier: "unknown_type",
                        message: description,
                        hint: nil,
                        details: ["type": Variant(type)])
        }
    }
}


/// Collection of object type violation errors produced when checking object
/// types.
///
/// - SeeAlso: ``ObjectSnapshot/check(conformsTo:)``
///
public struct ObjectTypeErrorCollection: Error {
    public let errors: [ObjectTypeError]
    
    public init(_ underlyingErrors: [ObjectTypeError]) {
        self.errors = underlyingErrors
    }
}

/// Error generated when a frame is checked for constraints and object types.
///
/// This error is produced by the ``ConstraintChecker/check(_:)``.
///
public struct FrameValidationError: Error {
    /// List of constraint violations.
    ///
    public let violations: [ConstraintViolation]
    
    /// List of object type errors.
    ///
    public let objectErrors: [ObjectID: [ObjectTypeError]]
    
    public let edgeRuleViolations: [ObjectID: [EdgeRuleViolation]]
    
    /// Broken referential integrity of a frame. Keys are offending objects,
    /// values is a list of IDs that are not present in the frame.
    public let brokenReferences: [ObjectID]
    
    /// Create a new constraint validation error.
    ///
    public init(violations: [ConstraintViolation],
                objectErrors: [ObjectID:[ObjectTypeError]],
                edgeRuleViolations: [ObjectID:[EdgeRuleViolation]],
                brokenReferences: [ObjectID] = []) {
        self.violations = violations
        self.objectErrors = objectErrors
        self.edgeRuleViolations = edgeRuleViolations
        self.brokenReferences = brokenReferences
    }
    
    public func asDesignIssueCollection() -> DesignIssueCollection {
        var result: DesignIssueCollection = DesignIssueCollection()
        for violation in violations {
            for object in violation.objects {
                let issue = DesignIssue(
                    domain: .validation,
                    severity: .error,
                    identifier: "constraint_violation",
                    message: violation.constraint.abstract ?? "Constraint violation",
                    details: [
                        "constraint": Variant(violation.constraint.name)
                    ]
                )
                result.append(issue, for: object)
            }
        }
        
        for (id, errors) in objectErrors {
            for error in errors {
                result.append(error.asDesignIssue(), for: id)
            }
        }
        for (id, errors) in edgeRuleViolations {
            for error in errors {
                result.append(error.asDesignIssue(), for: id)
            }
        }
        // TODO: This is provided only for debug purposes, broken references are an application error and should never be surfaced to the user.
        
        for id in brokenReferences {
            let issue = DesignIssue(
                domain: .validation,
                severity: .fatal,
                identifier: "broken_reference",
                message: "Broken object reference"
            )
            result.append(issue, for: id)

        }
        return result
    }
}

