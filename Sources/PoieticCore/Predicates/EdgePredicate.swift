//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 17/06/2022.
//


/// Predicate that tests the edge object itself together with its objects -
/// origin and target.
///
public class EdgeObjectPredicate: EdgePredicate {
    // FIXME: Is this still required?
    // FIXME: I do not like this class
    // TODO: Use CompoundPredicate
    
    let originPredicate: NodePredicate?
    let targetPredicate: NodePredicate?
    let edgePredicate: EdgePredicate?
    
    public init(origin: NodePredicate? = nil,
                target: NodePredicate? = nil,
                edge: EdgePredicate? = nil) {
        guard !(origin == nil && target == nil && edge == nil) else {
            preconditionFailure("At least one of the parameters must be set: origin, target or edge")
        }
        
        self.originPredicate = origin
        self.targetPredicate = target
        self.edgePredicate = edge
    }
    
    public func match(graph: Graph, edge: Edge) -> Bool {
        if let predicate = originPredicate {
            let node = graph.node(edge.origin)!
            if !predicate.match(graph: graph, node: node) {
                return false
            }
        }
        if let predicate = targetPredicate {
            let node = graph.node(edge.target)!
            if !predicate.match(graph: graph, node: node) {
                return false
            }
        }
        if let predicate = edgePredicate {
            if !predicate.match(graph: graph, edge: edge) {
                return false
            }
        }
        return true
    }
}
