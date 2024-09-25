//
//  ConstraintChecker.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 18/09/2024.
//

// FIXME: [REFACTORING] Rename methods

public class ConstraintChecker {
    let metamodel: Metamodel
    
    public init(_ metamodel: Metamodel) {
        self.metamodel = metamodel
    }
    
    public func validate(object: ObjectSnapshot, trait: Trait) throws (ErrorCollection<ObjectTypeError>) {
        var errors = ErrorCollection<ObjectTypeError>()
        
        for attr in trait.attributes {
            if let value = object[attr.name] {

                // TODO: Enable type checking
                // For type validation to work correctly we must make sure that
                // the types are persisted and restored.
                //
                if !value.valueType.isConvertible(to: attr.type) {
                    let error = ObjectTypeError.typeMismatch(attr, value.valueType)
                    errors.append(error)
                }
            }
            else if attr.optional {
                continue
            }
            else {
                let error = ObjectTypeError.missingTraitAttribute(attr, trait.name)
                errors.append(error)
            }
        }
        
        if !errors.isEmpty {
            throw errors
        }
    }
    public func checkConstraints(_ frame: Frame) throws (ErrorCollection<ConstraintViolation>) {
        var violations: [ConstraintViolation] = []
        for constraint in metamodel.constraints {
            let violators = constraint.check(frame)
            if violators.isEmpty {
                continue
            }
            let violation = ConstraintViolation(constraint: constraint,
                                                objects:violators)
            violations.append(violation)
        }
        guard violations.isEmpty else {
            throw ErrorCollection(violations)
        }
    }
    /// Validates a frame for constraints violations and referential integrity.
    ///
    /// This function first check whether the structural referential integrity
    /// is assured – whether the structural details and parent-child hierarchy
    /// have valid object references.
    ///
    /// Secondly the function check the constraints and collect all detected
    /// violations that can be identified.
    ///
    /// If there are any constraint violations found, then the
    /// ``ConstraintViolationError`` is thrown with a list of all detected
    /// violations.
    ///
    /// - Throws: `ConstraintViolationError` when the frame contents violates
    ///   constraints of the design.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``
    ///
    public func validate(frame: Frame) throws (FrameValidationError) {
        // Check types
        // ------------------------------------------------------------
        var typeErrors: [ObjectID: [ObjectTypeError]] = [:]
        
        for object in frame.snapshots {
            guard let type = metamodel.objectType(name: object.type.name) else {
                let error = ObjectTypeError.unknownType(object.type.name)
                typeErrors[object.id, default: []].append(error)
                continue
            }
            
            for trait in type.traits {
                do {
                    try validate(object: object, trait: trait)
                }
                catch let error as ErrorCollection<ObjectTypeError> {
                    typeErrors[object.id, default: []] += error.errors
                }
            }
        }

        // Check constraints
        // ------------------------------------------------------------
        let violations: [ConstraintViolation]
        
        do {
            try checkConstraints(frame)
            violations = []
        }
        catch let error as ErrorCollection<ConstraintViolation> {
            violations = error.errors
        }
        catch {
            // FIXME: [IMPORTANT] COMPILER SEGFAULTS if this catch is not here
            fatalError("Something very confusing just happened")
        }
        
        guard violations.isEmpty && typeErrors.isEmpty else {
            throw FrameValidationError(violations: violations,
                                       typeErrors: typeErrors)
        }
    }


}

/// Error thrown when constraint violations were detected in the graph during
/// `accept()`.
///
public struct FrameValidationError: Error {
    public let violations: [ConstraintViolation]
    public let typeErrors: [ObjectID: [ObjectTypeError]]
    
    public init(violations: [ConstraintViolation]=[], typeErrors: [ObjectID:[ObjectTypeError]]) {
        self.violations = violations
        self.typeErrors = typeErrors
    }
    
    public var prettyDescriptionsByObject: [ObjectID: [String]] {
        var result: [ObjectID:[String]] = [:]
        
        for violation in violations {
            let message = violation.constraint.abstract ?? "(no constraint description)"
            let desc = "[\(violation.constraint.name)] \(message)"
            for id in violation.objects {
                result[id, default: []].append(desc)
            }
        }
        
        return result
    }

}

