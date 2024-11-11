//
//  NodeConstraints.swift
//  
//
//  Created by Stefan Urbanek on 16/06/2022.
//

public final class UniqueNeighbourRequirement: ConstraintRequirement {
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
    ///     - selector: neigborhood selector that has to be unique for the
    ///       matching node
    ///     - required: Wether the unique neighbour is required.
    ///
    public init(_ selector: NeighborhoodSelector, required: Bool=false) {
        self.selector = selector
        self.isRequired = required
    }

    
    public func check(frame: some Frame, objects: [any ObjectSnapshot]) -> [ObjectID] {
        return objects.filter {
            guard $0.structure.type == .node else {
                return false
            }
            let hood = frame.hood($0.id, selector: self.selector)
            let count = hood.edges.count
            
            return count > 1 || (count == 0 && isRequired)
        }
        .map { $0.id }
    }
}
