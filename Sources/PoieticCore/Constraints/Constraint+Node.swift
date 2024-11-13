//
//  NodeConstraints.swift
//  
//
//  Created by Stefan Urbanek on 16/06/2022.
//

/// Requirement that there must be at most one edge adjacent to a tested node.
///
public final class UniqueNeighbourRequirement: ConstraintRequirement {
    /// Predicate to test the adjacent edges.
    public let predicate: Predicate
    
    /// Direction of the edge relative to the node being tested for the requirement.
    public let direction: EdgeDirection
    
    /// Flag whether at least one edge is required. If true, then the edge matching
    /// the predicate must exist.
    public let isRequired: Bool
    
    /// Creates a constraint for unique neighbour.
    ///
    /// If the unique neighbour is required, then the constraint fails if there
    /// is no neighbour matching the edge selector. If the neighbour is not
    /// required, then the constraint succeeds either where there is exactly
    /// one neighbour or when there is none.
    ///
    /// - Parameters:
    ///     - predicate: Predicate to select neighbourhood edges.
    ///     - direction: Edge direction to consider relative to the object tested.
    ///     - required: Wether the unique neighbour is required.
    ///
    public init(_ predicate: Predicate, direction: EdgeDirection = .outgoing, required: Bool=false) {
        self.predicate = predicate
        self.direction = direction
        self.isRequired = required
    }
    
    public func check(frame: some Frame, objects: [any ObjectSnapshot]) -> [ObjectID] {
        return objects.filter {
            guard $0.structure.type == .node else {
                return false
            }
            let hood = frame.hood($0.id, direction: direction) { edge in
                predicate.match(edge.snapshot, in: frame)
            }
            let count = hood.edges.count
            
            return count > 1 || (count == 0 && isRequired)
        }
        .map { $0.id }
    }
}
