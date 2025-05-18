//
//  ConstraintErrors.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 26/09/2024.
//

/// Type error detail produced when checking object types against a metamodel.
///
/// - SeeAlso: ``ObjectSnapshotProtocol/check(conformsTo:)``
///
public enum ObjectTypeError: Error, Equatable, CustomStringConvertible, DesignIssueConvertible {
    
    /// Object type is not known in the metamodel.
    case unknownType(String)

    /// Object is missing a required attribute from a trait.
    case missingTraitAttribute(Attribute, String)
    
    /// Value for an attribute is not convertible to a required type as
    /// specified in the trait owning the attribute.
    /// 
    /// - SeeAlso: ``ObjectSnapshotProtocol/check(conformsTo:)``,
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
/// - SeeAlso: ``ObjectSnapshotProtocol/check(conformsTo:)``
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
    /// - SeeAlso: ``Metamodel/constraints``, ``Constraint``.
    ///
    public let violations: [ConstraintViolation]
    
    /// List of object type errors.
    ///
    /// - SeeAlso: ``Metamodel/types``, ``ObjectType``.
    ///
    public let objectErrors: [ObjectID: [ObjectTypeError]]
    
    /// Violations of edge rules.
    ///
    /// - SeeAlso: ``Metamodel/edgeRules``, ``EdgeRule``.
    ///
    public let edgeRuleViolations: [ObjectID: [EdgeRuleViolation]]
    
    /// Create a new constraint validation error.
    ///
    /// - Parameters:
    ///     - violations: List of ``Constraint`` violations.
    ///     - objectErrors: List of errors caused by not conforming to ``ObjectType``
    ///     - edgeRuleViolations: List of ``EdgeRule`` violations.
    ///
    /// - SeeAlso: ``Metamodel/constraints``, ``Metamodel/types``, ``Metamodel/edgeRules``.
    ///
    public init(violations: [ConstraintViolation],
                objectErrors: [ObjectID:[ObjectTypeError]],
                edgeRuleViolations: [ObjectID:[EdgeRuleViolation]]) {
        self.violations = violations
        self.objectErrors = objectErrors
        self.edgeRuleViolations = edgeRuleViolations
    }
    
    /// Converts the validation error into an application oriented design issue.
    ///
    /// This method is used when the errors are to be presented by an application. For example
    /// in an error browser or by an object error inspector.
    ///
    public func asDesignIssueCollection() -> DesignIssueCollection {
        var result: DesignIssueCollection = DesignIssueCollection()
        // TODO: Use object-less design issues
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

        return result
    }
}

