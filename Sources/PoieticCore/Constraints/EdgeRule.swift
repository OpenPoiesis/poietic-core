//
//  ConnectionRule.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2025.
//

/// Designation of which direction of an edge from a node projection perspective
/// is to be considered.
///
public enum EdgeDirection: Sendable, CustomStringConvertible {
    /// Direction that considers edges where the node projection is the target.
    case incoming
    /// Direction that considers edges where the node projection is the origin.
    case outgoing
    
    /// Reversed direction. For ``incoming`` reversed is ``outgoing`` and
    /// vice-versa.
    ///
    public var reversed: EdgeDirection {
        switch self {
        case .incoming: return .outgoing
        case .outgoing: return .incoming
        }
    }
    public var description: String {
        switch self {
        case .incoming: "incoming"
        case .outgoing: "outgoing"
        }
    }
}

public enum EdgeRuleViolation: Error, CustomStringConvertible {
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
}
extension EdgeRuleViolation /*: IssueProtocol */ {
    public var message: String { description }
    public var hints: [String] { ["Consult the metamodel"] }
    
    public func asObjectIssue() -> Issue {
        switch self {
        case .edgeNotAllowed:
            Issue(
                identifier: "edge_not_allowed",
                severity: .error,
                system: "EdgeRule",
                message: self.description,
                hints: self.hints
                )
        case .noRuleSatisfied:
            Issue(
                identifier: "no_edge_rule_satisfied",
                severity: .error,
                system: "EdgeRule",
                message: self.description,
                hints: self.hints
                )
        case let .cardinalityViolation(rule, direction):
            Issue(
                identifier: "edge_cardinality_violated",
                severity: .error,
                system: "EdgeRule",
                message: self.description,
                hints: self.hints,
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

/// Defines which edges are allowed in the design graph and how they can be connected.
///
/// Edge rules are part of the design's **Constraint Validity** defined by design's ``Metamodel``.
/// Each edge in a design must match at least one edge rule, and the matched rule's cardinality
/// constraints must be satisfied.
///
/// There are two validation use-cases using ``ConstraintChecker``:
///
/// - **Pre-validation** (``ConstraintChecker/canConnect(type:from:to:in:)``): Checks if a new
///   edge *could* be created. Used in interactive UIs before creating the edge.
/// - **Validation** (``ConstraintChecker/validate(edge:in:)``): Checks existing edges in a frame.
///   Used when accepting frames into the design.
///
/// To collect all issues with edges (and other constraints) within a design you can use
/// ``ConstraintChecker/diagnose(_:)``.
///
/// ## Rule Matching Process
///
/// An edge matches a rule when ALL of the following conditions are met:
///
/// 1. The edge's ``ObjectType`` matches the rule's ``type``
/// 2. If ``originPredicate`` is specified, the edge's origin node must satisfy it
/// 3. If ``targetPredicate`` is specified, the edge's target node must satisfy it
/// 4. The number of matching edges at the origin satisfies ``outgoing`` cardinality
/// 5. The number of matching edges at the target satisfies ``incoming`` cardinality
///
/// ## Examples
///
/// **Example 1: Unrestricted connections**
///
/// ```swift
/// // Allow any node to connect to any node via Parameter edge
/// let parameterRule = EdgeRule(
///     type: ObjectType.Parameter,
///     // No predicates = any node matches
///     outgoing: .many,  // Multiple parameters can originate from same node
///     incoming: .many   // Multiple parameters can target same node
/// )
/// ```
///
/// **Example 2: Restricted connections with cardinality**
///
/// ```swift
/// // Flow edge must connect Stock (origin) to FlowRate (target)
/// // Each flow has exactly one source and one drain
/// let flowRule = EdgeRule(
///     type: ObjectType.Flow,
///     origin: IsTypePredicate(ObjectType.Stock),
///     outgoing: .many,  // Stock can have many outgoing flows
///     target: IsTypePredicate(ObjectType.FlowRate),
///     incoming: .one    // FlowRate has exactly one incoming flow
/// )
/// ```
/// 
/// ## Rule Ordering and Precedence
///
/// When multiple rules exist for the same edge type, the first matching rule is used.
/// More specific rules (with predicates) should be listed before general rules.
///
/// - Important: There must be at least one rule for each edge type defined in the metamodel.
///   Edges without any matching rule will fail validation with ``EdgeRuleViolation/edgeNotAllowed``.
///
/// - SeeAlso: ``Metamodel/edgeRules``, ``ConstraintChecker``, ``EdgeCardinality``,
///   ``Predicate``, ``EdgeDirection``
///
public struct EdgeRule: Sendable, CustomStringConvertible {
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
    /// be created. For validating existing edges see ``ConstraintChecker/validate(edge:in:)``.
    ///
    /// - SeeAlso: ``ConstraintChecker/canConnect(type:from:to:in:)``, ``ConstraintChecker/validate(edge:in:)``
    ///
    @inlinable
    public func match(_ type: ObjectType, origin: ObjectSnapshot, target: ObjectSnapshot, in frame: some Frame) -> Bool {
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
