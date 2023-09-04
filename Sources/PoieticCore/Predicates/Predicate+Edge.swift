//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 17/06/2022.
//


/// Predicate that tests the edge object itself together with its objects -
/// origin and target.
///
public class EdgeObjectPredicate: Predicate {
    // FIXME: Is this still required?
    // FIXME: I do not like this class
    // TODO: Use CompoundPredicate
    
    let originPredicate: Predicate?
    let targetPredicate: Predicate?
    let edgePredicate: Predicate?
    
    public init(origin: Predicate? = nil,
                target: Predicate? = nil,
                edge: Predicate? = nil) {
        guard !(origin == nil && target == nil && edge == nil) else {
            preconditionFailure("At least one of the parameters must be set: origin, target or edge")
        }
        
        self.originPredicate = origin
        self.targetPredicate = target
        self.edgePredicate = edge
    }
    
    public func match(frame: Frame, object: ObjectSnapshot) -> Bool {
        let graph = frame.graph
        
        guard let edge = Edge(object) else {
            return false
        }
        if let predicate = originPredicate {
            let node = graph.node(edge.origin)
            if !predicate.match(frame: frame, object: node.snapshot) {
                return false
            }
        }
        if let predicate = targetPredicate {
            let node = graph.node(edge.target)
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
