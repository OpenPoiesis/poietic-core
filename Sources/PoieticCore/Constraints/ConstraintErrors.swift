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
public enum ObjectTypeError: Error, Equatable, CustomStringConvertible {
    
    /// Object type is not known in the metamodel.
    ///
    /// - SeeAlso: ``ObjectProtocol/type``, ``Metamodel/types``
    ///
    case unknownType(String)
    
    /// Object topology does not match required type topology.
    ///
    /// - SeeAlso: ``ObjectType/topologyType``, ``ObjectProtocol/topology``
    ///
    case topologyMismatch(TopologyType)
    
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
        case let .topologyMismatch(type):
            "Topology mismatch. Expected \(type)"
        case let .missingTraitAttribute(attribute, trait):
            "Missing attribute '\(attribute.name)' required by trait '\(trait)'"
        case let .typeMismatch(attribute, actualType):
            "Type mismatch of attribute '\(attribute.name)', \(actualType) is not convertible to \(attribute.type)"
        }
    }
}
extension ObjectTypeError: IssueConvertible {
    public static let IssueSourceName: String = "validation"
   
    public var issueIdentifier: String {
        switch self {
        case .unknownType(_): "object_type.unknown_type"
        case .topologyMismatch(_): "object_type.topology_mismatch"
        case .missingTraitAttribute(_,_): "object_type.missing_trait_attribute"
        case .typeMismatch(_,_): "object_type.type_mismatch"
        }
    }
    public var message: String { description }

    public var hints: [String] { [
        "Consult the metamodel",
    ] }

    public var details: [String: Variant] {
        switch self {
        case let .unknownType(type):
            ["type": Variant(type)]
        case let .topologyMismatch(type):
            ["expected_topology": Variant(type.rawValue)]
        case let .missingTraitAttribute(attribute, trait):
            [
              "attribute": Variant(attribute.name),
              "trait": Variant(trait)
            ]
        case let .typeMismatch(attribute, _):
            [
              "attribute": Variant(attribute.name),
              "expected_type": Variant(attribute.type.description)
            ]
        }
    }
}


/// Error thrown by constraint checker when there are issues with a plane.
///
/// - SeeAlso: ``ConstraintChecker/validate(_:)``
///
public enum PlaneValidationError: Error {
    /// Topological references such as edge endpoints, parent-child are invalid.
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

/// Collection of plane validation issues.
///
/// This collection is produced by ``ConstraintChecker/diagnose(_:)``.
///
/// - SeeAlso: ``PlaneValidationError`` for an exception complement.
///
public struct PlaneValidationResult: Sendable {
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
                source: "validation",
                message: message,
                relatedObjects: violation.objects
                )
            result.append(issue)
        }
        return result
    }
    
    public static let IssueSourceName: String = "PlaneValidation"
    
    /// Convert object errors and edge rule violations to object issues.
    ///
    /// This method is used for unified error output.
    ///
    public func objectIssues() -> [ObjectID:[Issue]] {
        var result: [ObjectID:[Issue]] = [:]
        for (id, errors) in objectErrors {
            for error in errors {
                let issue = Issue(
                    identifier: error.issueIdentifier,
                    severity: .error,
                    source: Self.IssueSourceName,
                    message: error.message,
                    hints: error.hints,
                    details: error.details,
                )
                result[id, default: []].append(issue)
            }
        }
        for (id, errors) in edgeRuleViolations {
            for error in errors {
                let issue = Issue(
                    identifier: error.issueIdentifier,
                    severity: .error,
                    source: Self.IssueSourceName,
                    message: error.message,
                    hints: error.hints,
                    details: error.details,
                )
                result[id, default: []].append(issue)
            }
        }
        return result
    }
}

