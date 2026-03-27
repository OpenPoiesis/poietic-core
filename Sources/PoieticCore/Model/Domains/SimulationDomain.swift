//
//  SimulationDomain.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2025.
//

// TODO: Add SimulationSettings trait (from Trait.Simulation in Flows)

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
    
    /// Trait for objects that can be represented by a numeric value.
    ///
    public static let NumericValue = Trait(
        name: "NumericValue",
        attributes: [
            Attribute("display_value_min", type: .double, optional: true,
                      abstract: "Typically expected minimum value"),
            Attribute("display_value_max", type: .double, optional: true,
                      abstract: "Typically expected maxim value"),
            Attribute("display_value_baseline", type: .double, optional: true,
                      abstract: "Typically expected middle value for differentiating positive and negative relative to the mid-value"),
            Attribute("display_value_auto_scale", type: .bool, optional: true,
                      abstract: "Scale the min/max display value bounds based on the data"),
        ],
        abstract: "Trait for objects that might have a visual numeric indicator"
    )
}
