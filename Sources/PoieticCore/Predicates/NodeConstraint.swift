//
//  NodeConstraints.swift
//  
//
//  Created by Stefan Urbanek on 16/06/2022.
//

/// An object representing constraint that checks nodes.
///
public class NodeConstraint: Constraint {
    public let name: String
    public let description: String?
    public let match: NodePredicate
    public let requirement: NodeConstraintRequirement
    
    /// Creates a node constraint.
    ///
    /// - Properties:
    ///
    ///     - name: Constraint name
    ///     - description: Constraint description
    ///     - match: a node predicate that matches nodes to be considered for
    ///       this constraint
    ///     - requirement: a requirement that needs to be satisfied by the
    ///       matched nodes.
    ///

    public init(name: String, description: String? = nil, match: NodePredicate, requirement: NodeConstraintRequirement) {
        self.name = name
        self.description = description
        self.match = match
        self.requirement = requirement
    }

    /// Check the graph for the constraint and return a list of nodes that
    /// violate the constraint
    ///
    public func check(_ graph: Graph) -> [ObjectID] {
        let matched = graph.nodes.filter {
            match.match(graph: graph, node: $0)
        }

        return requirement.check(graph: graph, nodes: matched)
    }
}

/// Definition of a constraint satisfaction requirement.
///
public protocol NodeConstraintRequirement {
    /// Check whether the constraint requirement is satisfied within the group
    /// of provided nodes.
    ///
    /// - Returns: List of graph objects that cause constraint violation.
    ///
    func check(graph: Graph, nodes: [Node]) -> [ObjectID]
}


public class UniqueNeighbourRequirement: NodeConstraintRequirement {
    public let selector: NeighborhoodSelector
    public let isRequired: Bool
    
    /// Creates a constraint for unique neighbour.
    ///
    /// If the unique neighbour is required, then the constraint fails if there
    /// is no neighbour matching the edge selector. If the neighbour is not
    /// required, then the constraint succeeds either where there is exactly
    /// one neighbour or when there is none.
    ///
    /// - Parameters:
    ///     - nodeLabels: labels that match the nodes for the constraint
    ///     - edgeSelector: edge selector that has to be unique for the matching node
    ///     - required: Wether the unique neighbour is required.
    ///
    public init(_ selector: NeighborhoodSelector, required: Bool=false) {
        self.selector = selector
        self.isRequired = required
    }

    
    public func check(graph: Graph, node: Node) -> Bool {
        let hood = graph.hood(node.id, selector: self.selector)
        
        return (isRequired && hood.edges.count == 1)
                || (!isRequired && hood.edges.count <= 1)
    }

    public func check(graph: Graph, nodes: [Node]) -> [ObjectID] {
        return nodes.filter { !check(graph: graph, node: $0) }
            .map { $0.id }
    }
}
