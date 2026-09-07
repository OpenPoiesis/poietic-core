//
//  SimulationDomain.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 29/10/2025.
//

// TODO: Add SimulationSettings trait (from Trait.Simulation in Flows)

extension Trait {
    /// Tag trait denoting that an object specifies a simulation scenario.
    public static let Scenario = Trait(
        name: "Scenario",
        attributes: [ /* Just a tag */ ]
    )

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
    
    /// Trait that specifies simulation start time, time step and final time.
    ///
    /// Attributes:
    ///
    /// - `start_time` (double) – initial time of the simulation, default is 0.0
    /// - `time_step` (double) – time between simulation steps, default is 1.0
    /// - `final_time` (double) – Final simulation time.
    ///
    public static let SimulationTime = Trait(
        // TODO: Split to SimulationTime and SimulationConfiguration
        name: "SimulationTime",
        attributes: [
            Attribute("start_time", type: .double,
                      default: Variant(0.0),
                      optional: true,
                      abstract: "Initial simulation time"
                     ),
            Attribute("time_step", type: .double,
                      default: Variant(1.0),
                      optional: true,
                      abstract: "Advancement of time for each simulation step"
                     ),
            Attribute("final_time", type: .double,
                      default: Variant(10.0),
                      optional: true,
                      abstract: "Final simulation time"
                     ),
        ]
    )

}
