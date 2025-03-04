//
//  ConstraintChecker.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 18/09/2024.
//

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
    /// - Throws: ``ObjectConstraintError`` when the object does not conform
    ///   to the trait.
    ///
    public func check(conformsTo trait: Trait) throws (ObjectTypeErrorCollection) {
        var errors:[ObjectTypeError] = []
        
        for attr in trait.attributes {
            if let value = self[attr.name] {

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
            throw ObjectTypeErrorCollection(errors)
        }
    }
}

/// An object that checks constraints, including object types, of a frame.
///
/// Constraint checker is used to validate a frame whether it conforms to a given metamodel.
///
/// One can validate a frame against different metamodels which are not associated with the design
/// owning a frame.
///
public struct ConstraintChecker {
    // NOTE: This object could have been a function, but I like the steps to be separated.
    
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
    ///   See ``ObjectSnapshot/check(conformsTo:)``) for more information.
    /// - Objects must conform to all the constraints specified in the
    ///   metamodel.
    ///
    /// - Throws: ``FrameConstraintError`` if a constraint violation or a
    ///   type error is found, otherwise returns nil.
    ///
    /// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``ObjectSnapshot/check(conformsTo:)``
    ///
    public func check(_ frame: some Frame) throws (FrameValidationError) {
        var errors: [ObjectID: [ObjectTypeError]] = [:]
        var edgeViolations: [ObjectID: [EdgeRuleViolation]] = [:]
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
                    errors[object.id, default: []].append(contentsOf: error.errors)
                }
            }
            
            if let edge = EdgeSnapshot(object, in: frame) {
                do {
                    try validate(edge: edge, in: frame)
                }
                catch {
                    edgeViolations[object.id, default: []].append(error)
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
                && errors.isEmpty
                && edgeViolations.isEmpty else {
            throw FrameValidationError(violations: violations,
                                       objectErrors: errors,
                                       edgeRuleViolations: edgeViolations)
        }
    }
    
    public func validate(edge: EdgeSnapshot<DesignObject>, in frame: some Frame) throws (EdgeRuleViolation) {
        let typeRules = metamodel.edgeRules.filter {
            edge.object.type === $0.type
        }
        if typeRules.count == 0 {
            throw .edgeNotAllowed
        }
        guard let matchingRule = typeRules.first(where: { rule in
            rule.match(edge, in: frame)
        }) else {
            throw .noRuleSatisfied(edge.object.type)
        }

        let outgoingCount = frame.outgoing(edge.origin).count { $0.object.type === matchingRule.type }
        switch matchingRule.outgoing {
        case .many: break
        case .one:
            if outgoingCount != 1 {
                throw .cardinalityViolation(matchingRule, .outgoing)
            }
        }
        
        let incomingCount = frame.incoming(edge.target).count { $0.object.type === matchingRule.type }
        switch matchingRule.incoming {
        case .many: break
        case .one:
            if incomingCount != 1 {
                throw .cardinalityViolation(matchingRule, .incoming)
            }
        }
    }
}

