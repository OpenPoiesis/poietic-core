//
//  ConstraintChecker.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 18/09/2024.
//

// FIXME: [REFACTORING] Rename methods

extension Array<ObjectTypeError>: @retroactive Error {
    
}

extension ObjectSnapshot {
    
    /// Checks object's conformance to a trait.
    ///
    /// The object conforms to a trait if the following is true:
    ///
    /// - Object has values for all traits required attributes
    /// - All attributes from the trait that are present in the object
    ///   must be convertible to the type of the corresponding trait attribute.
    ///
    /// For each non-met requirement an error is included in the result.
    ///
    /// - Parameters:
    ///     - `trait`: Trait to be used for checking
    ///
    /// - Returns: List of conformance errors as ``ObjectError``.
    ///
    public func check(conformsTo trait: Trait) throws (ObjectConstraintError) {
        var errors:[ObjectTypeError] = []
        
        for attr in trait.attributes {
            if let value = self[attr.name] {

                // TODO: Enable type checking
                // For type validation to work correctly we must make sure that
                // the types are persisted and restored.
                //
                if !value.isRepresentable(as: attr.type) {
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
        
        guard errors.isEmpty else {
            throw ObjectConstraintError(underlyingErrors: errors)
        }
    }
}

/// An object that checks constraints, including object types, of a frame.
///
public struct ConstraintChecker {
    /// Metamodel associated with the constraint checker. Frames and objects
    /// will be validated using the constraints and object types defined
    /// in the metamodel.
    ///
    public let metamodel: Metamodel
    
    /// Create a new constraint checker and associate it with a metamodel.
    ///
    /// The objects and frames will be validated against constraints and
    /// object types in the metamodel.
    ///
    public init(_ metamodel: Metamodel) {
        self.metamodel = metamodel
    }
    
    /// Check a frame for constraints violations and object type conformance.
    ///
    /// The function first checks that:
    ///
    /// - All objects have a type from the metamodel.
    /// - Object conforms to traits of the object's type.
    ///   See ``ObjectSnapshot/checkConformance(to:)``) for more information.
    /// - Objects must conform to all the constraints specified in the
    ///   metamodel.
    ///
    /// - Returns: ``ConstraintCheckResutl`` if a constraint violation or a
    ///   type error is found, otherwise returns nil.
    ///
    /// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``ObjectSnapshot/checkConformance(to:)``
    ///
    public func check(_ frame: Frame) throws (FrameConstraintError) {
        var errors: [ObjectID: [ObjectTypeError]] = [:]

        // Check types
        // ------------------------------------------------------------
        for object in frame.snapshots {
            guard let type = metamodel.objectType(name: object.type.name) else {
                let error = ObjectTypeError.unknownType(object.type.name)
                errors[object.id, default: []].append(error)
                continue
            }
            
            for trait in type.traits {
                do {
                    try object.check(conformsTo: trait)
                }
                catch {
                    errors[object.id, default: []].append(contentsOf: error.underlyingErrors)
                }
            }
        }

        // Check constraints
        // ------------------------------------------------------------
        var violations: [ConstraintViolation] = []
        for constraint in metamodel.constraints {
            let violators = constraint.check(frame)
            if !violators.isEmpty {
                violations.append(ConstraintViolation(constraint: constraint,
                                                      objects: violators))
            }
        }

        // Throw an error if there are any violations or errors
        
        guard violations.isEmpty
                && (errors.isEmpty
                    || errors.values.allSatisfy({$0.isEmpty})) else{
            throw FrameConstraintError(violations: violations,
                                       objectErrors: errors)
        }
    }
}

