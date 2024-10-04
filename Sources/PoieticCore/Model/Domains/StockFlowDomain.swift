//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 10/06/2024.
//

import Foundation

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
            Attribute("formula", type: .string,
                      abstract: "Arithmetic formula or a constant value represented by the node."
                     ),
        ]
    )
    
    /// Trait of nodes representing a stock.
    ///
    /// Analogous concept to a stock is an accumulator, container, reservoir
    /// or a pool.
    ///
    public static let Stock = Trait(
        name: "Stock",
        attributes: [
            Attribute("allows_negative", type: .bool,
                      default: Variant(false),
                      abstract: "Flag whether the stock can contain a negative value."
                     ),
            Attribute("delayed_inflow", type: .bool,
                      default: Variant(false),
                      abstract: "Flag whether the inflow of the stock is delayed by one step, when the stock is part of a cycle."
                     ),
        ]
    )
    
    /// Trait of nodes representing a flow.
    ///
    /// Flow is a node that can be connected to two stocks by a flow edge.
    /// One stock is an inflow - stock from which the node drains,
    /// and another stock is an outflow - stock to which the node fills.
    ///
    /// - Note: Current implementation considers are flows to be one-directional
    ///         flows. Flow with negative value, which is in fact an outflow,
    ///         will be ignored.
    ///
    public static let Flow = Trait(
        name: "Flow",
        attributes: [
            /// Priority specifies an order in which the flow will be considered
            /// when draining a non-negative stocks. The lower the number, the higher
            /// the priority.
            ///
            /// - Note: It is highly recommended to specify priority explicitly if a
            /// functionality that considers the priority is used. It is not advised
            /// to rely on the default priority.
            ///
            Attribute("priority", type: .int, default: Variant(0),
                      abstract: "Priority during computation. The flows are considered in the ascending order of priority."),
        ]
    )
    
    /// Trait of a node representing a graphical function.
    ///
    /// Graphical function is a function defined by its points and an
    /// interpolation method that is used to compute values between the points.
    ///
    public static let GraphicalFunction = Trait(
        name: "GraphicalFunction",
        attributes: [
            Attribute("interpolation_method", type: .string, default: "step",
                      abstract: "Method of interpolation for values between the points."),
            Attribute("graphical_function_points", type: .points,
                      default: Variant(Array<Point>()),
                      abstract: "Points of the graphical function."),
        ],
        abstract: "Function represented by a set of points and an interpolation method."
    )
    
    public static let Delay = Trait(
        name: "Delay",
        attributes: [
            Attribute("delay_duration", type: .double, default: Variant(1),
                      abstract: "Delay duration in time units."),
            Attribute("delay_output_type", type: .string, default: Variant("delay"), optional: true,
                      abstract: "Type of delay output computation"),
//            Attribute("delay_output_order", type: .int, default: Variant(0), optional: true,
//                      abstract: "Order of the delay"),
            // TODO: Implement: DELAY1, DELAY3,DELAYN, SMTH1, 3, N
        ]
    )

    
    /// Trait of a node that represents a chart.
    ///
    public static let Chart = Trait(
        name: "Chart",
        attributes: [
//            AttributeDescription(
//                name: "chartType",
//                type: .string,
//                abstract: "Chart type"),
        ]
    )

    public static let Control = Trait(
        name: "Control",
        attributes: [
            Attribute("value",
                      type: .double,
                      default: Variant(0.0),
                      abstract: "Value of the target node"),
            Attribute("control_type",
                      type: .string,
                      optional: true,
                      abstract: "Visual type of the control"),
            Attribute("min_value",
                      type: .double,
                      optional: true,
                      abstract: "Minimum possible value of the target variable."),
            Attribute("max_value",
                      type: .double,
                      optional: true,
                      abstract: "Maximum possible value of the target variable."),
            Attribute("step_value",
                      type: .double,
                      optional: true,
                      abstract: "Step for a slider control."),
            // TODO: numeric (default), percent, currency
            Attribute("value_format",
                      type: .string,
                      optional: true,
                      abstract: "Display format of the value"),

        ]
    )

    /// Trait with simulation defaults.
    ///
    /// This trait is used to specify default values of a simulation such as
    /// initial time or time delta in the model. Users usually override
    /// these values in an application performing the simulation.
    ///
    /// Attributes:
    ///
    /// - `initial_time` (double) – initial time of the simulation, default is
    ///    0.0 as most commonly used value
    /// - `time_delta` (double) – time delta, default is 1.0 as most commonly
    ///   used value
    /// - `steps` (int) – default number of simulation steps, default is 10
    ///    (arbitrary, low number just enough to demonstrate something)
    ///
    public static let Simulation = Trait(
        name: "Simulation",
        attributes: [
            Attribute("steps", type: .int,
                      default: Variant(10),
                      optional: true,
                      abstract: "Number of steps the simulation is run by default."
                     ),
            Attribute("initial_time", type: .double,
                      default: Variant(0.0),
                      optional: true,
                      abstract: "Initial simulation time."
                     ),
            Attribute("time_delta", type: .double,
                      default: Variant(1.0),
                      optional: true,
                      abstract: "Simulation step time delta."
                     ),
            // TODO: Add stop_time or final_time
            // TODO: Support date/time
            // TODO: Add Solver type
        ]
    )
}

extension ObjectType {
    /// A stock node - one of the two core nodes.
    ///
    /// Stock node represents a pool, accumulator, a stored value.
    ///
    /// Stock can be connected to many flows that drain or fill the stock.
    ///
    /// - SeeAlso: ``ObjectType/Flow``.
    ///
    public static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Formula,
            Trait.Stock,
            Trait.Position,
        ]
    )
    
    /// A flow node - one of the two core nodes.
    ///
    /// Flow node represents a rate at which a stock is drained or a stock
    /// is filed.
    ///
    /// Flow can be connected to only one stock that the flow fills and from
    /// only one stock that the flow drains.
    ///
    /// ```
    ///                    drains           fills
    ///     Stock source ----------> Flow ---------> Stock drain
    ///
    /// ```
    ///
    /// - SeeAlso: ``ObjectType/Stock``, ``ObjectType/Fills``,
    /// ``ObjectType/Drains``.
    ///
    public static let Flow = ObjectType(
        name: "Flow",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Formula,
            Trait.Flow,
            Trait.Position,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    /// An auxiliary node - containing a constant or a formula.
    ///
    public static let Auxiliary = ObjectType(
        name: "Auxiliary",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Formula,
            Trait.Position,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    /// An auxiliary node with a function that is described by a graph.
    ///
    /// Graphical function is specified by a collection of 2D points.
    ///
    public static let GraphicalFunction = ObjectType(
        name: "GraphicalFunction",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Position,
            Trait.GraphicalFunction,
            // DescriptionComponent.self,
            // ErrorComponent.self,
            // TODO: IMPORTANT: Make sure we do not have formula component here or handle the type
        ]
    )

    /// An auxiliary node - containing a constant or a formula.
    ///
    public static let Delay = ObjectType(
        name: "Delay",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Position,
            Trait.Delay,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    /// A user interface mode representing a control that modifies a value of
    /// its target node.
    ///
    /// For control node to work, it should be connected to its target node with
    /// ``/PoieticCore/ObjectType/ValueBinding`` edge.
    ///
    public static let Control = ObjectType(
        name: "Control",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Control,
        ]
    )
    
    /// A user interface node representing a chart.
    ///
    /// Chart contains series that are connected with the chart using the
    /// ``/PoieticCore/ObjectType/ChartSeries`` edge where the origin is the chart and
    /// the target is a value node.
    ///
    public static let Chart = ObjectType(
        name: "Chart",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Chart,
        ]
    )
    
    /// A node that contains a note, a comment.
    ///
    /// The note is not used for simulation, it exists solely for the purpose
    /// to provide user-facing information.
    ///
    public static let Note = ObjectType(
        name: "Note",
        structuralType: .node,
        traits: [
            Trait.Note,
        ]
    )
    
    /// Edge from a stock to a flow. Denotes "what the flow drains".
    ///
    /// - SeeAlso: ``/PoieticCore/ObjectType/Flow``, ``/PoieticCore/ObjectType/Fills``
    ///
    public static let Drains = ObjectType(
        name: "Drains",
        structuralType: .edge,
        traits: [
            // None for now
        ],
        abstract: "Edge from a stock node to a flow node, representing what the flow drains."
    )
    
    /// Edge from a flow to a stock. Denotes "what the flow fills".
    ///
    /// - SeeAlso: ``/PoieticCore/ObjectType/Flow``, ``/PoieticCore/ObjectType/Drains``
    ///
    public static let Fills = ObjectType(
        name: "Fills",
        structuralType: .edge,
        traits: [
            // None for now
        ],
        abstract: "Edge from a flow node to a stock node, representing what the flow fills."
        
    )
    
    /// An edge between a node that serves as a parameter in another node.
    ///
    /// For example, if a flow has a formula `rate * 10` then the node
    /// with name `rate` is connected to the flow through the parameter edge.
    ///
    public static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: .edge,
        traits: [
            // None for now
        ]
    )
    
    /// An edge type to connect controls with their targets.
    ///
    /// The origin of the node is a control – ``/PoieticCore/ObjectType/Control``, the
    /// target is a node representing a value.
    ///
    public static let ValueBinding = ObjectType(
        name: "ValueBinding",
        structuralType: .edge,
        traits: [
            // None for now
        ],
        abstract: "Edge between a control and a value node. The control observes the value after each step."
    )
    
    /// An edge type to connect a chart with a series that are included in the
    /// chart.
    ///
    /// The origin of the node is a chart – ``/PoieticCore/ObjectType/Chart`` and
    /// the target of the node is a node representing a value.
    ///
    public static let ChartSeries = ObjectType(
        // TODO: Origin: Chart, target: Expression
        name: "ChartSeries",
        structuralType: .edge,
        traits: [
            // None for now
        ],
        abstract: "Edge between a control and its target."
    )
    // ---------------------------------------------------------------------

    // Scenario
    
    public static let Scenario = ObjectType(
        name: "Scenario",
        structuralType: .node,
        traits: [
            Trait.Name,
            Trait.Documentation,
        ]
        
        // Outgoing edges: ValueBinding with attribute "value"
    )
    
    public static let Simulation = ObjectType (
        name: "Simulation",
        structuralType: .unstructured,
        traits: [
            Trait.Simulation,
        ]
    )
}



extension Metamodel {
    /// The metamodel for Stock-and-Flows domain model.
    ///
    /// The `FlowsMetamodel` describes concepts, components, constraints and
    /// queries that define the [Stock and Flow](https://en.wikipedia.org/wiki/Stock_and_flow)
    /// model domain.
    ///
    /// The basic object types are: ``/PoieticCore/ObjectType/Stock``, ``ObjectType/Flow``, ``ObjectType/Auxiliary``. More advanced
    /// node type is ``/PoieticCore/ObjectType/GraphicalFunction``.
    ///
    /// - SeeAlso: `Metamodel` protocol description for more information and reasons
    /// behind this approach of describing the metamodel.
    ///
    public static let StockFlow = Metamodel(
        name: "StockFlow",
        /// List of components that are used in the Stock and Flow models.
        ///
        traits: [
            Trait.Name,
            Trait.Stock,
            Trait.Flow,
            Trait.Formula,
            Trait.Position,
            Trait.GraphicalFunction,
            Trait.Chart,
            Trait.Simulation,
            Trait.BibliographicalReference,
        ],
        
        // NOTE: If we were able to use Mirror on types, we would not need this
        /// List of object types for the Stock and Flow metamodel.
        ///
        types: [
            // Nodes
            ObjectType.Stock,
            ObjectType.Flow,
            ObjectType.Auxiliary,
            ObjectType.GraphicalFunction,
            ObjectType.Delay,

            // Edges
            ObjectType.Drains,
            ObjectType.Fills,
            ObjectType.Parameter,
            
            // UI
            ObjectType.Control,
            ObjectType.Chart,
            ObjectType.ChartSeries,
            ObjectType.ValueBinding,
            
            // Other
            ObjectType.Simulation,
            ObjectType.BibliographicalReference,
            ObjectType.Note,
        ],
        
        // MARK: Constraints
        // TODO: Add tests for violation of each of the constraints
        // --------------------------------------------------------------------
        /// List of constraints of the Stock and Flow metamodel.
        ///
        /// The constraints include:
        ///
        /// - Flow must drain (from) a stock, no other kind of node.
        /// - Flow must fill (into) a stock, no other kind of node.
        ///
        constraints: [
            Constraint(
                name: "flow_fill_is_stock",
                abstract: """
                      Flow must drain (from) a stock, no other kind of node.
                      """,
                match: EdgePredicate(IsTypePredicate(ObjectType.Fills)),
                requirement: AllSatisfy(
                    EdgePredicate(
                        origin: IsTypePredicate(ObjectType.Flow),
                        target: IsTypePredicate(ObjectType.Stock)
                    )
                )
            ),
            
            Constraint(
                name: "flow_drain_is_stock",
                abstract: """
                      Flow must fill (into) a stock, no other kind of node.
                      """,
                match: EdgePredicate(IsTypePredicate(ObjectType.Drains)),
                requirement: AllSatisfy(
                    EdgePredicate(
                        origin: IsTypePredicate(ObjectType.Stock),
                        target: IsTypePredicate(ObjectType.Flow)
                    )
                )
            ),
            
            Constraint(
                name: "one_parameter_for_graphical_function",
                abstract: """
                      Graphical function must not have more than one incoming parameters.
                      """,
                match: IsTypePredicate(ObjectType.GraphicalFunction),
                requirement: UniqueNeighbourRequirement(
                    NeighborhoodSelector(
                        predicate: IsTypePredicate(ObjectType.Parameter),
                        direction: .incoming
                    ),
                    required: false
                )
            ),
            
            // UI
            // TODO: Make the value binding target to be "Value" type (how?)
            Constraint(
                name: "control_value_binding",
                abstract: """
                      Control binding's origin must be a Control and target must be a formula node.
                      """,
                match: EdgePredicate(IsTypePredicate(ObjectType.ValueBinding)),
                requirement: AllSatisfy(
                    EdgePredicate(
                        origin: IsTypePredicate(ObjectType.Control),
                        target: HasTraitPredicate(Trait.Formula)
                    )
                )
            ),
            Constraint(
                name: "chart_series",
                abstract: """
                      Chart series edge must originate in Chart and end in Value node.
                      """,
                match: EdgePredicate(IsTypePredicate(ObjectType.ChartSeries)),
                requirement: AllSatisfy(
                    EdgePredicate(
                        origin: IsTypePredicate(ObjectType.Chart),
                        target: HasTraitPredicate(Trait.Formula)
                    )
                )
            ),
            Constraint(
                name: "control_target_must_be_aux_or_stock",
                abstract: """
                      Control target must be Auxiliary or a Stock node.
                      """,
                match: EdgePredicate(
                    IsTypePredicate(ObjectType.ValueBinding),
                    origin: IsTypePredicate(ObjectType.Control)
                ),
                requirement: AllSatisfy(
                    EdgePredicate(
                        target: IsTypePredicate(ObjectType.Auxiliary)
                            .or(IsTypePredicate(ObjectType.Stock))
                    )
                )
            ),
            
        ]
    )
}
