//
//  SimulationDomain.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2025.
//

// Simulation related traits

// TODO: Add SimulationObject trait
// TODO: Add TimeSeries trait
// TODO: Add NumericValue trait

extension Trait {
    /// Trait of simulation nodes that are computed using an arithmetic formula.
    ///
    /// Variables used in the formula refer to other nodes by their name. Nodes
    /// referring to other nodes as parameters must have an edge from the
    /// parameter nodes to the nodes using the parameter.
    ///
    /// Attributes:
    ///
    /// - `formula` (`string`):  Arithmetic formula.
    ///
    /// - SeeAlso: ``ArithmeticExpression``
    ///
    public static let Formula = Trait(
        name: "Formula",
        attributes: [
            Attribute("formula", type: .string, default: "0",
                      abstract: "Arithmetic formula or a constant value represented by the node"
                     ),
        ]
    )
}
