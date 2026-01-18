//
//  ConstraintErrors.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 26/09/2024.
//

/// Type error detail produced when checking object types against a metamodel.
///
/// - SeeAlso: ``ConstraintChecker/validate(_:conformsTo:)-(_,ObjectType)``
///
public enum ObjectTypeError: Error, Equatable, CustomStringConvertible, DesignIssueConvertible {
    
    /// Object type is not known in the metamodel.
    ///
    /// - SeeAlso: ``ObjectProtocol/type``, ``Metamodel/types``
    ///
    case unknownType(String)

    /// Object structure does not match required type structure.
    ///
    /// - SeeAlso: ``ObjectType/structuralType``, ``ObjectProtocol/structure``
    ///
    case structureMismatch(StructuralType)
    
    /// Object is missing a required attribute from a trait.
    ///
    /// - SeeAlso: ``Trait/attributes``
    ///
    case missingTraitAttribute(Attribute, String)
    
    /// Value for an attribute is not convertible to a required type as
    /// specified in the trait owning the attribute.
    /// 
    /// - SeeAlso: ``Attribute/type``, ``VariableType/isConvertible(to:)``,
    ///   ``Variant/isConvertible(to:)``, ``Variant/isRepresentable(as:)``
    ///
    case typeMismatch(Attribute, ValueType)
    
    public var description: String {
        switch self {
        case let .unknownType(name):
            "Unknown object type: \(name)"
        case let .structureMismatch(type):
            "Structure mismatch. Expected \(type)"
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
        case let .structureMismatch(type):
            DesignIssue(domain: .validation,
                        severity: .error,
                        identifier: "structure_mismatch",
                        message: description,
                        hint: nil,
                        details: [
                            "expected_structure": Variant(type.rawValue)
                        ])
        }
    }
}

extension ObjectTypeError /*: IssueProtocol */ {
    public var message: String { description }
    public var hints: [String] { ["Consult the metamodel"] }
    
    public func asObjectIssue() -> Issue {
        switch self {
        case let .missingTraitAttribute(attribute, trait):
            Issue(
                identifier: "missing_trait_attribute",
                severity: .fatal,
                system: "Validation",
                message: self.description,
                details: [
                    "attribute": Variant(attribute.name),
                    "trait": Variant(trait)
                ])
        case let .typeMismatch(attribute, _):
            Issue(
                identifier: "attribute_type_mismatch",
                severity: .fatal,
                system: "Validation",
                message: self.description,
                details: [
                    "attribute": Variant(attribute.name),
                    "expected_type": Variant(attribute.type.description)
                ])
        case let .unknownType(type):
            Issue(
                identifier: "unknown_type",
                severity: .fatal,
                system: "Validation",
                message: self.description,
                details: ["type": Variant(type)])
        case let .structureMismatch(type):
            Issue(
                identifier: "structure_mismatch",
                severity: .fatal,
                system: "Validation",
                message: self.description,
                details: [
                    "expected_structure": Variant(type.rawValue)
                ])
        }
    }
}


/// Error thrown by constraint checker when there are issues with a frame.
///
/// - SeeAlso: ``ConstraintChecker/validate(_:)``
///
public enum FrameValidationError: Error {
    /// Structural references such as edge endpoints, parent-child are invalid.
    ///
    /// When this error happens, it is not possible to do further diagnostics. It usually means
    /// a programming error.
    case brokenStructuralIntegrity(StructuralIntegrityError)
    
    /// Thrown when an object does not match its type.
    ///
    /// - See: ``ConstraintChecker/validate(_:conformsTo:)-(_,ObjectType)``, ``Metamodel/types``,
    ///   ``ObjectType``
    ///
    case objectTypeError(ObjectID, ObjectTypeError)
    
    /// Thrown when an edge violates edge rules.
    /// - SeeAlso: ``ConstraintChecker/validate(edge:in:)``, ``Metamodel/edgeRules``
    ///
    case edgeRuleViolation(ObjectID, EdgeRuleViolation)

    /// Thrown when any of the objects violate a metamodel constraint.
    ///
    /// - SeeAlso: ``Metamodel/constraints``
    case constraintViolation(ConstraintViolation)
    
    /// Flag whether the caller can diagnose details about constraint violations using
    /// ``ConstraintChecker/diagnose(_:)`` after this error.
    ///
    public var canDiagnoseConstraints: Bool {
        switch self {
        case .brokenStructuralIntegrity: false
        default: true
        }
    }
}

/// Collection of frame validation issues.
///
/// This collection is produced by ``ConstraintChecker/diagnose(_:)``.
///
/// - SeeAlso: ``FrameValidationError`` for an exception complement.
///
public struct FrameValidationResult: Sendable {
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

    /// True if there are no violations.
    public var isValid: Bool {
        violations.isEmpty && objectErrors.isEmpty && edgeRuleViolations.isEmpty
    }
    
    
    /// Convert violations to object issues.
    ///
    /// This method is used for unified error output.
    ///
    public func violationsAsIssues() -> [Issue] {
        var result: [Issue] = []
        for violation in violations {
            let constraint = violation.constraint
            let message = constraint.name
                            + (constraint.abstract.map { ": " + $0 }  ?? "")
            let issue = Issue(
                identifier: "constraint_violation:",
                severity: .error,
                system: "Validation",
                message: message,
                relatedObjects: violation.objects
                )
            result.append(issue)
        }
        return result
    }
    
    /// Convert object errors and edge rule violations to object issues.
    ///
    /// This method is used for unified error output.
    ///
    public func objectIssues() -> [ObjectID:[Issue]] {
        var result: [ObjectID:[Issue]] = [:]
        for (id, errors) in objectErrors {
            for error in errors {
                let issue = error.asObjectIssue()
                result[id, default: []].append(issue)
            }
        }
        for (id, errors) in edgeRuleViolations {
            for error in errors {
                let issue = error.asObjectIssue()
                result[id, default: []].append(issue)
            }
        }
        return result
    }
}

