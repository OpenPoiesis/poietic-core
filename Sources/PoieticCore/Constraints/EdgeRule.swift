//
//  ConnectionRule.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2025.
//


public enum EdgeRuleViolation: Error, Equatable, CustomStringConvertible, DesignIssueConvertible {
    case edgeNotAllowed
    case noRuleSatisfied
    case cardinalityViolation(EdgeRule, EdgeDirection)
    
    public var description: String {
        switch self {
        case .edgeNotAllowed: "Edge type is not allowed"
        case .noRuleSatisfied: "None of edge rules is satisfied"
        case let .cardinalityViolation(rule, direction): "Cardinality violation for rule \(rule) direction \(direction)"
        }
    }
    
    public static func ==(lhs: EdgeRuleViolation, rhs: EdgeRuleViolation) -> Bool {
        switch (lhs, rhs) {
        case (.edgeNotAllowed, .edgeNotAllowed):
            true
        case (.noRuleSatisfied, .noRuleSatisfied):
            true
        case let (.cardinalityViolation(lrule, ldir), .cardinalityViolation(rrule, rdir)):
            lrule == rrule && ldir == rdir
        default:
            false
        }
    }
    
    public func asDesignIssue() -> DesignIssue {
        switch self {
        case .edgeNotAllowed:
            DesignIssue(domain: .validation,
                        severity: .error,
                        identifier: "edge_not_allowed",
                        message: description,
                        hint: nil,
                        details: [:])
        case .noRuleSatisfied:
            DesignIssue(domain: .validation,
                        severity: .error,
                        identifier: "no_edge_rule_satisfied",
                        message: description,
                        hint: nil,
                        details: [:])
        case let .cardinalityViolation(rule, direction):
            DesignIssue(domain: .validation,
                        severity: .error,
                        identifier: "edge_cardinality_violated",
                        message: description,
                        hint: nil,
                        details: [
                            "incoming_predicate": Variant(rule.incoming.description),
                            "outgoing_predicate": Variant(rule.outgoing.description),
                            "direction": Variant(direction.description)
                            ]
                        )
        }
    }
}

// TODO: Rename to ConnectionRule

/// Rule for edges that are allowed in the design.
///
/// Each edge in the design must conform to the connection rules defined by this object.
///
/// For example, to allow any kind of connection of a given edge type, say `Cause`, we can use
/// the following:
///
/// ```swift
/// let Cause = ObjectType(name: "Cause", structuralType: .edge)
/// let metamodel = Metamodel(
///     types: [
///         Cause,
///         // more types ...
///     ],
///     edgeRules: [
///         EdgeRule(Cause)
///     ]
/// )
/// ```
///
/// - SeeAlso: ``Metamodel/edgeRules``, ``ConstraintChecker/validate(edge:in:)``
///
public struct EdgeRule: Equatable, Sendable, CustomStringConvertible {
    // NOTE: When changing/adding edge rule properties, make sure we can validate
    //       a new edge where the object does not exist yet. That is, we have only origin, target
    //       and a minimum of other properties that have to be passed to the validation function.
    //       Currently we require only the object type.
    
    /// Type of an edge object that the rule applies to.
    ///
    /// There must be at least one rule for each allowed edge type.
    ///
    public let type: ObjectType
    
    /// Predicate to check the origin object of an edge to match.
    ///
    /// If not set, then any origin object matches.
    ///
    public let originPredicate: Predicate?

    /// Allowed cardinality at the origin endpoint of the edge.
    ///
    /// The outgoing edges of the type that matches the rule must have given cardinality. For
    /// example, if the cardinality is ``EdgeCardinality/one``, then only one edge of the matching
    /// rule must originate in the same object.
    ///
    public let outgoing: EdgeCardinality

    /// Predicate to check the target object of an edge to match.
    ///
    /// If not set, then any target object matches.
    ///
    public let targetPredicate: Predicate?

    /// Allowed cardinality at the target endpoint of the edge.
    ///
    /// The incoming edges of the type that matches the rule must have given cardinality. For
    /// example, if the cardinality is ``EdgeCardinality/one``, then only one edge of the matching
    /// rule must target in the same object.
    ///
    public let incoming: EdgeCardinality
    
    /// Create a new edge rule.
    ///
    /// - Parameters:
    ///     - type: Type of an edge to be matched.
    ///     - origin: Predicate for the origin object of the matched edge. If not set, any object
    ///       matches.
    ///     - outgoing: Cardinality of the outgoing edges from the origin object.
    ///     - target: Predicate for the target object of the matched edge. If not set, any object
    ///       matches.
    ///     - incoming: Cardinality of the incoming edges to the target object.
    ///
    /// There must be at least one rule per allowed edge type in the metamodel.
    ///
    /// - SeeAlso: ``Metamodel/edgeRules``
    ///
    public init(type: ObjectType,
                origin: Predicate? = nil,
                outgoing: EdgeCardinality = .many,
                target: Predicate? = nil,
                incoming: EdgeCardinality = .many) {
        assert(type.structuralType == .edge)
        self.type = type
        self.originPredicate = origin
        self.targetPredicate = target
        self.outgoing = outgoing
        self.incoming = incoming
    }
    
    /// Validates whether the given edge matches the rule.
    ///
    /// The edge matches the rule if all of the following is satisfied:
    /// - edge type is the same as the type defined in the rule
    /// - if the origin predicate is defined, then the edge's origin must match the origin predicate
    /// - if the origin predicate is not defined, then any edge's origin matches
    /// - if the target predicate is defined, then the edge's target must match the target predicate
    /// - if the target predicate is not defined, then any edge's target matches
    ///
    /// - Returns `true` when the edge matches, `false` when the edge does not match the rule.
    ///
    /// This method is used for existing edges. To use for a potential new edge see ``match(_:origin:target:in:)``.
    ///
    /// - SeeAlso: ``ConstraintChecker/validate(edge:in:)``, ``ConstraintChecker/canConnect(type:from:to:in:)``
    ///
    public func match(_ edge: EdgeObject, in frame: some Frame) -> Bool {
        return match(edge.object.type, origin: edge.originObject, target: edge.targetObject, in: frame)
    }
    
    /// Validates whether the given edge type with given origin and target matches the rule.
    ///
    /// The edge matches the rule if all of the following is satisfied:
    /// - type is the same as the type defined in the rule
    /// - if the origin predicate is defined, then the edge's origin must match the origin predicate
    /// - if the origin predicate is not defined, then any edge's origin matches
    /// - if the target predicate is defined, then the edge's target must match the target predicate
    /// - if the target predicate is not defined, then any edge's target matches
    ///
    /// - Returns `true` when the edge matches, `false` when the edge does not match the rule.
    ///
    /// This method is typically used for potential new edges, to check whether they can or can not
    /// be created. For existing edges see ``match(_:in:)``.
    ///
    /// - SeeAlso: ``ConstraintChecker/canConnect(type:from:to:in:)``, ``ConstraintChecker/validate(edge:in:)``, ``match(_:in:)``
    ///
    @inlinable
    public func match(_ type: ObjectType, origin: DesignObject, target: DesignObject, in frame: some Frame) -> Bool {
        guard type === self.type else {
            return false
        }
        if let predicate = originPredicate {
            if !predicate.match(origin, in: frame) {
                return false
            }
        }
        
        if let predicate = targetPredicate {
            if !predicate.match(target, in: frame) {
                return false
            }
        }

        return true
    }
    
    public static func ==(lhs: EdgeRule, rhs: EdgeRule) -> Bool {
        return lhs.type === rhs.type
        // && lhs.originPredicate == rhs.originPredicate
        // FIXME: [IMPORTANT] Add predicates once Predicate is Comparable
    }

    public var description: String {
        var text: String = "IS \(type.name) FROM \(outgoing.description) ("

        if let originPredicate {
            text += "\(originPredicate)"
        }
        else {
            text += "any"
        }
        text += ") TO \(incoming.description) ("
        if let targetPredicate {
            text += "\(targetPredicate)"
        }
        else {
            text += "any"
        }
        text += ")"
        return text
    }
}
