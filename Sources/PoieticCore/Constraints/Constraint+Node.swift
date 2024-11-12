//
//  NodeConstraints.swift
//  
//
//  Created by Stefan Urbanek on 16/06/2022.
//

public final class UniqueNeighbourRequirement: ConstraintRequirement {
    public let predicate: Predicate
    public let direction: EdgeDirection
    public let isRequired: Bool
    
    /// Creates a constraint for unique neighbour.
    ///
    /// If the unique neighbour is required, then the constraint fails if there
    /// is no neighbour matching the edge selector. If the neighbour is not
    /// required, then the constraint succeeds either where there is exactly
    /// one neighbour or when there is none.
    ///
    /// - Parameters:
    ///     - selector: neigborhood selector that has to be unique for the
    ///       matching node
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
                predicate.match(frame: frame, object: edge.snapshot)
            }
            let count = hood.edges.count
            
            return count > 1 || (count == 0 && isRequired)
        }
        .map { $0.id }
    }
}
