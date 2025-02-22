//
//  ConnectionRule.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/02/2025.
//

/**
 edge       origin  target    origin outgoing    target incoming
 ---
 parameter  aux     aux         many    many
 parameter  stock   aux         many    many
 parameter  flow    aux         many    many
 
 parameter  aux     flow        many    many
 parameter  flow    flow        many    many
 
 parameter  aux     gr func     many    one
 parameter  stock   gr func     many    one
 parameter  flow    gr func     many    one
 flow       stock   flow        many    one
 flow       flow    stock       one    many
 flow       cloud   flow        many    one
 flow       flow    cloud       one    many
 comment    any     any         many    many
 

 */

public enum EdgeRuleViolation: Error, Equatable, CustomStringConvertible {
    case edgeNotAllowed
    case noSatisfiedRule(ObjectType)
    case cardinalityViolation(EdgeRule, EdgeDirection)
    
    public var description: String {
        switch self {
        case .edgeNotAllowed: "Edge not allowed"
        case let .noSatisfiedRule(type): "None of rules for edge type \(type.name) is satisfied"
        case let .cardinalityViolation(rule, direction): "Cardinality violation for rule \(rule) direction \(direction)"
        }
    }
    
    public static func ==(lhs: EdgeRuleViolation, rhs: EdgeRuleViolation) -> Bool {
        switch (lhs, rhs) {
        case (.edgeNotAllowed, .edgeNotAllowed):
            true
        case let (.noSatisfiedRule(ltype), .noSatisfiedRule(rtype)):
            ltype === rtype
        case let (.cardinalityViolation(lrule, ldir), .cardinalityViolation(rrule, rdir)):
            lrule == rrule && ldir == rdir
        default:
            false
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
                print("--x no match origin")
                return false
            }
        }
        
        if let predicate = targetPredicate {
            if !predicate.match(edge.targetObject, in: frame) {
                print("--x no match target")
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
