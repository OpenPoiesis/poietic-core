//
//  ConstraintChecker.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 18/09/2024.
//

/// An object that validates frame against a metamodel and checks constraints, object types and
/// edge rules.
///
/// There are two primary functions:
///
/// - ``validate(_:)``: Validates the frame and throws ``FrameValidationError`` on first validation
///   issue detected.
/// - ``diagnose(_:)``: Collects all the validation issues and returns them in
///   ``FrameValidationResult``.
///
/// The primary information used for validation is the ``Metamodel``:
///
/// - ``ObjectType`` from ``Metamodel/types``
/// - ``Constraint`` from ``Metamodel/constraints``
/// - ``EdgeRule`` from ``Metamodel/edgeRules``
///
/// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``StructuralValidator``.
///
public struct ConstraintChecker {
    // IMPORTANT: Maintain validate(...) and diagnose(...) function pairs in sync.
    // =========
    
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
    
    public func validate(_ object: some ObjectProtocol, conformsTo type: ObjectType) throws (ObjectTypeError) {
        if object.structure.type != type.structuralType  {
            throw .structureMismatch(object.type.structuralType)
        }
        
        for trait in type.traits {
            try validate(object, conformsTo: trait)
        }

    }
    public func diagnose(_ object: some ObjectProtocol, conformsTo type: ObjectType) -> [ObjectTypeError] {
        var errors:[ObjectTypeError] = []
        if object.structure.type != type.structuralType  {
            errors.append(.structureMismatch(object.type.structuralType))
        }
        
        for trait in type.traits {
            errors += diagnose(object, conformsTo: trait)
        }
        return errors
    }
    /// Validate object's conformance to a trait.
    ///
    /// The object conforms to a trait if the following is true:
    ///
    /// - Object has values for all traits required attributes
    /// - All attributes from the trait that are present in the object
    ///   must be convertible to the type of the corresponding trait attribute.
    ///
    /// - Parameters:
    ///     - `trait`: Trait to be used for checking
    ///
    /// - Throws: ``ObjectTypeError`` for first violation detected.
    /// - SeeAlso: ``diagnose(_:conformsTo:)-(_,Trait)`` for collecting all issues with an object.
    ///
    public func validate(_ object: some ObjectProtocol, conformsTo trait: Trait) throws (ObjectTypeError) {
        for attr in trait.attributes {
            if let value = object[attr.name] {
                // For type validation to work correctly we must make sure that
                // the types are persisted and restored.
                //
                guard value.isRepresentable(as: attr.type) else {
                    throw .typeMismatch(attr, value.valueType)
                }
            }
            else if attr.optional {
                continue
            }
            else {
                throw .missingTraitAttribute(attr, trait.name)
            }
        }
    }

    /// Validate object's conformance to a trait and collect all issues.
    ///
    /// The object conforms to a trait if the following is true:
    ///
    /// - Object has values for all traits required attributes
    /// - All attributes from the trait that are present in the object
    ///   must be convertible to the type of the corresponding trait attribute.
    ///
    /// - Parameters:
    ///     - `trait`: Trait to be used for checking
    ///
    /// - Returns: A collection of detected issues.
    /// - SeeAlso: ``validate(_:conformsTo:)-(_,Trait)`` for failing fast on first error.
    ///
    public func diagnose(_ object: some ObjectProtocol, conformsTo trait: Trait) -> [ObjectTypeError] {
        var errors:[ObjectTypeError] = []
        
        for attr in trait.attributes {
            if let value = object[attr.name] {
                if !value.isRepresentable(as: attr.type) {
                    errors.append(.typeMismatch(attr, value.valueType))
                }
            }
            else if attr.optional {
                continue
            }
            else {
                errors.append(.missingTraitAttribute(attr, trait.name))
            }
        }
        return errors
    }

    /// Check a frame for constraints violations and object type conformance.
    ///
    /// The function first checks that:
    ///
    /// - All objects have a type from the metamodel.
    /// - Object conforms to traits of the object's type.
    /// - Objects must conform to all the constraints specified in the
    ///   metamodel.
    ///
    /// The method collects all the errors. To only make sure that the frame is valid, see
    /// ``validate(_:)``, which throws on first error validation detected.
    ///
    /// - Returns: ``FrameValidationResult`` with collected validation diagnostic information.
    ///   Whether the frame is valid is indicated in the ``FrameValidationResult/isValid`` flag.
    ///
    /// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``validate(_:conformsTo:)-(_,ObjectType)``,
    ///   ``validate(edge:in:)``
    ///
    public func diagnose(_ frame: some Frame) -> FrameValidationResult {
        // IMPORTANT: Keep in sync with validate(...) version of this method
        var objectErrors: [ObjectID: [ObjectTypeError]] = [:]
        var edgeViolations: [ObjectID: [EdgeRuleViolation]] = [:]

        // 1. Check types
        for object in frame.snapshots {
            guard metamodel.hasType(object.type) else {
                objectErrors[object.objectID, default: []].append(.unknownType(object.type.name))
                continue // Nothing to validate, the object is not known to metamodel
            }
            let errors = diagnose(object, conformsTo: object.type)
            if !errors.isEmpty {
                objectErrors[object.objectID, default: []] += errors
            }
            
            if let edge = DesignObjectEdge(object, in: frame) {
                do {
                    try validate(edge: edge, in: frame)
                }
                catch {
                    edgeViolations[object.objectID, default: []].append(error)
                }
            }
        }

        // 2. Check constraints
        var violations: [ConstraintViolation] = []
        for constraint in metamodel.constraints {
            let violators = constraint.check(frame)
            if !violators.isEmpty {
                violations.append(ConstraintViolation(constraint: constraint,
                                                      objects: violators))
            }
        }

        return FrameValidationResult(
            violations: violations,
            objectErrors: objectErrors,
            edgeRuleViolations: edgeViolations
        )
    }
    
    /// Check a frame for constraints violations and object type conformance.
    ///
    /// The function first checks that:
    ///
    /// - All objects have a type from the metamodel.
    /// - Object conforms to traits of the object's type.
    /// - Objects must conform to all the constraints specified in the
    ///   metamodel.
    ///
    /// The method throws at first error detected. To collect all the errors, see ``diagnose(_:)``.
    ///
    /// - Throws: ``FrameValidationError`` if the frame violates constraints or does not satisfy
    ///   type requirements.
    ///
    /// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``validate(_:conformsTo:)-(_,ObjectType)``,
    ///   ``validate(edge:in:)``
    ///
    public func validate(_ frame: some Frame) throws (FrameValidationError) {
        // IMPORTANT: Keep in sync with diagnose(...) version of this method

        for object in frame.snapshots {
            guard metamodel.hasType(object.type) else {
                throw .objectTypeError(object.objectID, .unknownType(object.type.name))
            }
            do {
                try validate(object, conformsTo: object.type)
            }
            catch {
                throw .objectTypeError(object.objectID, error)
            }
            
            if let edge = DesignObjectEdge(object, in: frame) {
                do {
                    try validate(edge: edge, in: frame)
                }
                catch {
                    throw .edgeRuleViolation(edge.id, error)
                }
            }
        }

        for constraint in metamodel.constraints {
            let violators = constraint.check(frame)
            guard violators.isEmpty else {
                throw .constraintViolation(ConstraintViolation(constraint: constraint,
                                                               objects: violators))
            }
        }
    }

    /// Validates the edge whether it matches the metamodel's edge rules.
    ///
    /// The validation process is as follows:
    ///
    /// 1. Find all rules for given edge type. There must be at least one for the edge to be valid.
    ///    If no rules are found, then throws ``EdgeRuleViolation/edgeNotAllowed``.
    /// 2. Find first rule that matches the edge with ``ConstraintChecker/validate(edge:in:)``.
    ///    If no rule matches, then throws ``EdgeRuleViolation/noRuleSatisfied``.
    /// 3. Validates cardinality of the object type.
    ///
    /// To check whether an edge can be created, for example, when user tries to drag a new
    /// connection in a graphical application, see ``canConnect(type:from:to:in:)``.
    ///
    /// - SeeAlso: ``Metamodel/edgeRules``, ``EdgeRule``
    /// - Throws: ``EdgeRuleViolation``
    
    public func validate(edgeType: ObjectType, origin: ObjectID, target: ObjectID, in frame: some Frame) throws (EdgeRuleViolation) {
        // NOTE: Changes in this function should be synced with func canConnect(...)
        let originObject = frame[origin]!
        let targetObject = frame[target]!
        
        let typeRules = metamodel.edgeRules.filter { edgeType === $0.type }
        if typeRules.count == 0 {
            throw .edgeNotAllowed
        }
        guard let matchingRule = typeRules.first(where: { rule in
            rule.match(edgeType, origin: originObject, target: targetObject, in: frame)
        })
        else {
            throw .noRuleSatisfied
        }

        let outgoingCount = frame.outgoing(origin).count { $0.object.type === matchingRule.type }
        switch matchingRule.outgoing {
        case .many: break
        case .one:
            if outgoingCount != 1 {
                throw .cardinalityViolation(matchingRule, .outgoing)
            }
        }
        
        let incomingCount = frame.incoming(target).count { $0.object.type === matchingRule.type }
        switch matchingRule.incoming {
        case .many: break
        case .one:
            if incomingCount != 1 {
                throw .cardinalityViolation(matchingRule, .incoming)
            }
        }
    }
    public func validate(edge: DesignObjectEdge, in frame: some Frame) throws (EdgeRuleViolation) {
        // NOTE: Changes in this function should be synced with func canConnect(...)

        let typeRules = metamodel.edgeRules.filter { edge.object.type === $0.type }
        if typeRules.count == 0 {
            throw .edgeNotAllowed
        }
        guard let matchingRule = typeRules.first(where: { rule in
            rule.match(edge.object.type, origin: edge.originObject, target: edge.targetObject, in: frame)
        }) else {
            throw .noRuleSatisfied
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
    
    /// Test whether a new edge of given type can be created.
    ///
    /// The function tries to find a first rule for given edge type. If the edge endpoints match
    /// the rule and when the cardinality including with the new edge is satisfied, then
    /// the function returns `true`. Otherwise it returns `false`.
    ///
    /// Typical use of this function is in a graphical application to test whether a new connection
    /// can be mate. It can be done during a connection-dragging session where the possibility
    /// is indicated by a change of the mouse cursor or by other means.
    ///
    /// - SeeAlso: ``EdgeRule/match(_:origin:target:in:)``, ``validate(edge:in:)``
    ///
    public func canConnect(type: ObjectType, from originID: ObjectID, to targetID: ObjectID, in frame: some Frame) -> Bool {
        // NOTE: Changes in this function should be synced with func validate(...)
        
        let typeRules = metamodel.edgeRules.filter { type === $0.type }
        guard typeRules.count > 0 else {
            return false
        }
        guard let origin = frame[originID],
              let target = frame[targetID] else {
            return false
        }
        guard let matchingRule = typeRules.first(where: { rule in
            rule.match(type, origin: origin, target: target, in: frame)
        }) else {
            return false
        }

        let outgoingCount = frame.outgoing(originID).count { $0.object.type === matchingRule.type }
        switch matchingRule.outgoing {
        case .many: break
        case .one:
            return outgoingCount == 0
        }
        
        let incomingCount = frame.incoming(targetID).count { $0.object.type === matchingRule.type }
        switch matchingRule.incoming {
        case .many: break
        case .one:
            return incomingCount == 0
        }
        return true
    }

}

// TODO: A sketch, not yet used
public struct MetamodelValidationMode: OptionSet, Sendable {
    public let rawValue: Int8
    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
    public static let allowUnknownTypes = MetamodelValidationMode(rawValue: 1 << 0)
    public static let allowUnknownEdges = MetamodelValidationMode(rawValue: 1 << 1)
    public static let ignoreConstraints = MetamodelValidationMode(rawValue: 1 << 2)
                                                                                                                                                    
    public static let strict: MetamodelValidationMode = []
    public static let permissive: MetamodelValidationMode = [.allowUnknownTypes, .allowUnknownEdges, .ignoreConstraints]
}
