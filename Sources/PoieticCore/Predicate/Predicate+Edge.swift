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
    
    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        guard let edge = EdgeObject(object) else {
            return false
        }
        if let predicate = originPredicate {
            let node = frame.node(edge.origin)
            if !predicate.match(node, in: frame) {
                return false
            }
        }
        if let predicate = targetPredicate {
            let node = frame.node(edge.target)
            if !predicate.match(node, in: frame) {
                return false
            }
        }
        if let predicate = edgePredicate {
            if !predicate.match(edge.snapshot, in: frame) {
                return false
            }
        }
        return true
    }
}
