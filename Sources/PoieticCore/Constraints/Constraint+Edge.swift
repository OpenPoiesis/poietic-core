//
//  EdgeConstraints.swift
//  
//
//  Created by Stefan Urbanek on 16/06/2022.
//

/// Requirement that the edge origin, edge target and the edge itself matches
/// given labels.
///
public final class EdgeEndpointRequirement: ConstraintRequirement {
    /// Labels to be matched on the edge's origin, if provided.
    public let origin: IsTypePredicate?
    
    /// Labels to be matched on the edge's target, if provided.
    public let target: IsTypePredicate?
    
    /// Labels to be matched on the edge itself, if provided.
    public let edge: IsTypePredicate?

    /// Creates a constraint requirement for edges to assure that the origin,
    /// target and/or the edge itself are of a specific type.
    ///
    /// - Parameters:
    ///
    ///     - origin: Predicate that matches types of edge's origin.
    ///     - target: Predicate that matches types of edge's target.
    ///     - edge: Predicate that matches the edge's type.
    ///
    public init(origin: IsTypePredicate? = nil,
                target: IsTypePredicate? = nil,
                edge: IsTypePredicate? = nil) {
        guard !(origin == nil && target == nil && edge == nil) else {
            preconditionFailure("At least one of the parameters must be set: origin or target")
        }
        
        self.origin = origin
        self.target = target
        self.edge = edge
    }
    
    public func check(frame: some Frame, objects: [DesignObject]) -> [ObjectID] {
        var violations: [ObjectID] = []
        
        for object in objects {
            guard let edge = EdgeObject(object) else {
                fatalError("Object \(object.id) is not an edge")
            }

            if let predicate = self.origin {
                let node = frame.node(edge.origin)
                if !predicate.match(node, in: frame) {
                    violations.append(edge.id)
                    continue
                }
            }
            if let predicate = self.target {
                let node = frame.node(edge.target)
                if !predicate.match(node, in: frame) {
                    violations.append(edge.id)
                    continue
                }
            }
            if let predicate = self.edge, !predicate.match(edge.snapshot, in: frame) {
                violations.append(edge.id)
                continue
            }
        }

        return violations
    }
}
