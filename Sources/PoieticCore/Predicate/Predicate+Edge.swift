//
//  EdgePredicate.swift
//  
//
//  Created by Stefan Urbanek on 17/06/2022.
//


/// Predicate that tests the edge object itself together with its objects -
/// origin and target.
///
/// Only objects with structural type ``Structure/edge(_:_:)`` will
/// be matched by this predicate.
///
public final class EdgePredicate: Predicate {
    let edgePredicate: Predicate?
    let originPredicate: Predicate?
    let targetPredicate: Predicate?
    
    public init(_ edge: Predicate? = nil,
                origin: Predicate? = nil,
                target: Predicate? = nil) {
        guard !(origin == nil && target == nil && edge == nil) else {
            preconditionFailure("At least one of the parameters must be set: origin, target or edge")
        }
        
        self.originPredicate = origin
        self.targetPredicate = target
        self.edgePredicate = edge
    }
    
    public func match(frame: some Frame, object: some ObjectSnapshot) -> Bool {
        guard let edge = Edge(object) else {
            return false
        }
        if let predicate = originPredicate {
            let node = frame.node(edge.origin)
            if !predicate.match(frame: frame, object: node.snapshot) {
                return false
            }
        }
        if let predicate = targetPredicate {
            let node = frame.node(edge.target)
            if !predicate.match(frame: frame, object: node.snapshot) {
                return false
            }
        }
        if let predicate = edgePredicate {
            if !predicate.match(frame: frame, object: edge.snapshot) {
                return false
            }
        }
        return true
    }
}
