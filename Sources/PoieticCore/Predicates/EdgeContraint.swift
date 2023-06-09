//
//  EdgeConstraints.swift
//  
//
//  Created by Stefan Urbanek on 16/06/2022.
//

// TODO: Merge with NodeConstraint

/// An object representing constraint that checks edges.
///
public class EdgeConstraint: Constraint {
    /// Name of the constraint.
    ///
    /// See ``Constraint/name`` for more information.
    public let name: String
    
    /// Human readable description of the constraint. See ``Constraint/description``.
    ///
    public let description: String?

    /// A predicate that matches all edges to be considered for this constraint.
    ///
    /// See ``EdgePredicate`` for more information.
    ///
    public let match: EdgePredicate
    
    /// A requirement that needs to be satisfied for the matched edges.
    ///
    public let requirement: EdgeConstraintRequirement
    
    /// Creates an edge constraint.
    ///
    /// - Properties:
    ///
    ///     - name: Constraint name
    ///     - description: Constraint description
    ///     - match: an edge predicate that matches edges to be considered for
    ///       this constraint
    ///     - requirement: a requirement that needs to be satisfied by the
    ///       matched edges.
    ///
    public init(name: String, description: String? = nil, match: EdgePredicate, requirement: EdgeConstraintRequirement) {
        self.name = name
        self.description = description
        self.match = match
        self.requirement = requirement
    }

    /// Check the graph for the constraint and return a list of nodes that
    /// violate the constraint
    ///
    public func check(_ graph: Graph) -> [ObjectID] {
        let matched = graph.edges.filter {
            match.match(graph: graph, edge: $0)
        }
        return requirement.check(graph: graph, edges: matched)
    }
}

/// Definition of a constraint satisfaction requirement.
///
public protocol EdgeConstraintRequirement {
    /// Check whether the constraint requirement is satisfied within the group
    /// of provided edges.
    ///
    /// - Returns: List of graph objects that cause constraint violation.
    ///
    func check(graph: Graph, edges: [Edge]) -> [ObjectID]
}

/// Requirement that the edge origin, edge target and the edge itself matches
/// given labels.
///
public class EdgeEndpointTypes: EdgeConstraintRequirement {
    // TODO: Use CompoundPredicate?
    
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
    
    public func check(graph: Graph, edges: [Edge]) -> [ObjectID] {
        var violations: [ObjectID] = []
        
        for edge in edges {
            if let predicate = self.origin {
                let node = graph.node(edge.origin)!
                if !predicate.match(graph: graph, node: node) {
                    violations.append(edge.id)
                    continue
                }
            }
            if let predicate = self.target {
                let node = graph.node(edge.target)!
                if !predicate.match(graph: graph, node: node) {
                    violations.append(edge.id)
                    continue
                }
            }
            if let predicate = self.edge, !predicate.match(graph: graph, edge: edge) {
                violations.append(edge.id)
                continue
            }
        }

        return violations
    }
}
