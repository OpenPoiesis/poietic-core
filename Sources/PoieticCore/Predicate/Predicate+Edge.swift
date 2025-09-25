//
//  EdgePredicate.swift
//  
//
//  Created by Stefan Urbanek on 17/06/2022.
//

/**
 
 Constraints:
 
 Node:
    - predicate -> requirement
 
    requirement: object predicate
 
 Edge:
    - for EDGE of TYPE
    - edge (predicate, origin, target) -> requirement
    - requirement:
        - edge object requirement
        - origin object requirement
        - target object requirement
        - cardinality requirement (origin, target)
 
 */

public enum EdgeCardinality: Sendable, CustomStringConvertible {
    // case oneOrZero
    // case exactlyOne
    case one
    case many
    
    public var description: String {
        switch self {
        case .one: "one"
        case .many: "many"
        }
    }
}

/// Predicate that tests the edge object itself together with its objects -
/// origin and target.
///
/// Only objects with structural type ``Structure/edge(_:_:)`` will
/// be matched by this predicate.
///
public struct EdgePredicate: Predicate, CustomStringConvertible {
    let edgePredicate: Predicate?
    let originPredicate: Predicate?
    let targetPredicate: Predicate?
    
    public init() {
        self.edgePredicate = nil
        self.originPredicate = nil
        self.targetPredicate = nil
    }
    
    public init(_ edge: Predicate? = nil,
                origin: Predicate? = nil,
                target: Predicate? = nil) {
        self.edgePredicate = edge
        self.originPredicate = origin
        self.targetPredicate = target
    }
    
    public init(_ edgeType: ObjectType? = nil,
                origin: ObjectType? = nil,
                target: ObjectType? = nil) {
        self.edgePredicate = edgeType.map { IsTypePredicate($0) }
        self.originPredicate = origin.map { IsTypePredicate($0) }
        self.targetPredicate = target.map { IsTypePredicate($0) }
    }
    
    public func match(_ object: ObjectSnapshot, in frame: some DesignProtocol) -> Bool {
        guard let edge = EdgeObject(object, in: frame) else {
            return false
        }
        if let predicate = edgePredicate {
            if !predicate.match(object, in: frame) {
                return false
            }
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
    
    public var description: String {
        return "edge(\(String(describing: edgePredicate)), \(String(describing: originPredicate)), \(String(describing: targetPredicate))"
    }
}
