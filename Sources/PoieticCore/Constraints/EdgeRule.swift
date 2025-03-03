//
//  ConnectionRule.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2025.
//


public enum EdgeRuleViolation: Error, Equatable, CustomStringConvertible, DesignIssueConvertible {
    case edgeNotAllowed
    case noRuleSatisfied(ObjectType)
    case cardinalityViolation(EdgeRule, EdgeDirection)
    
    public var description: String {
        switch self {
        case .edgeNotAllowed: "Edge not allowed"
        case let .noRuleSatisfied(type): "None of rules for edge type \(type.name) is satisfied"
        case let .cardinalityViolation(rule, direction): "Cardinality violation for rule \(rule) direction \(direction)"
        }
    }
    
    public static func ==(lhs: EdgeRuleViolation, rhs: EdgeRuleViolation) -> Bool {
        switch (lhs, rhs) {
        case (.edgeNotAllowed, .edgeNotAllowed):
            true
        case let (.noRuleSatisfied(ltype), .noRuleSatisfied(rtype)):
            ltype === rtype
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
        case .noRuleSatisfied(_):
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
public struct EdgeRule: Equatable, Sendable, CustomStringConvertible {
    public let type: ObjectType
    public let originPredicate: Predicate?
    public let outgoing: EdgeCardinality
    public let targetPredicate: Predicate?
    public let incoming: EdgeCardinality
    
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
    
    func match(_ edge: EdgeSnapshot<DesignObject>, in frame: some Frame) -> Bool {
        guard edge.object.type === type else {
            return false
        }
        if let predicate = originPredicate {
            if !predicate.match(edge.originObject, in: frame) {
                return false
            }
        }
        
        if let predicate = targetPredicate {
            if !predicate.match(edge.targetObject, in: frame) {
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

public struct EdgeRuleChecker {
    public let metamodel: Metamodel
    
    public init(_ metamodel: Metamodel) {
        self.metamodel = metamodel
    }
    
    public func validate(edge: EdgeSnapshot<DesignObject>, in frame: some Frame) -> Bool {
        let edgeTypeRules =  metamodel.edgeRules.filter { rule in
            edge.object.type === rule.type
        }
        
        guard edgeTypeRules.count > 0 else {
            // No edge rules
            return true
        }

        guard let matchingRule = metamodel.edgeRules.first(where: { rule in
            rule.match(edge, in: frame)
        }) else {
            return false
        }
        
        let outgoingCount = frame.outgoing(edge.origin).count { $0.object.type === matchingRule.type }
        switch matchingRule.outgoing {
        case .many: break
        case .one:
            if outgoingCount != 1 {
                return false
            }
        }
        
        let incomingCount = frame.incoming(edge.target).count { $0.object.type === matchingRule.type }
        switch matchingRule.incoming {
        case .many: break
        case .one:
            if incomingCount != 1 {
                return false
            }
        }
        
        return true
    }
}
