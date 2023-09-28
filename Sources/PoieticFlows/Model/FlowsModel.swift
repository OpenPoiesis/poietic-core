//
//  Metamodel.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import PoieticCore

/// The metamodel for Stock-and-Flows domain model.
///
/// The `FlowsMetamodel` describes concepts, components, constraints and
/// queries that define the [Stock and Flow](https://en.wikipedia.org/wiki/Stock_and_flow)
/// model domain.
///
/// The basic object types are: ``Stock``, ``Flow``, ``Auxiliary``. More advanced
/// node type is ``GraphicalFunction``.
///
/// - SeeAlso: `Metamodel` protocol description for more information and reasons
/// behind this approach of describing the metamodel.
///
public class FlowsMetamodel: Metamodel {
    // MARK: Components
    // ---------------------------------------------------------------------

    public static let components: [Component.Type] = [
        NameComponent.self,
        StockComponent.self,
        FlowComponent.self,
        FormulaComponent.self,
        PositionComponent.self,
        GraphicalFunctionComponent.self,
        ChartComponent.self,
    ] + BasicMetamodel.components
    
    
    // MARK: Object Types
    // ---------------------------------------------------------------------


    public static let DesignInfo = BasicMetamodel.DesignInfo
    
    /// A stock node - one of the two core nodes.
    ///
    /// Stock node represents a pool, accumulator, a stored value.
    ///
    /// Stock can be connected to many flows that drain or fill the stock.
    ///
    /// - SeeAlso: ``FlowsMetamodel/Flow``, ``FlowsMetamodel/ImplicitFlow``
    ///
    public static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        components: [
            NameComponent.self,
            FormulaComponent.self,
            StockComponent.self,
            PositionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
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
    /// - SeeAlso: ``FlowsMetamodel/Stock``, ``FlowsMetamodel/Fills-8qqu8``,
    /// ``FlowsMetamodel/Drains-38oqw``.
    ///
    public static let Flow = ObjectType(
        name: "Flow",
        structuralType: .node,
        components: [
            NameComponent.self,
            FormulaComponent.self,
            FlowComponent.self,
            PositionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    /// An auxiliary node - containing a constant or a formula.
    ///
    public static let Auxiliary = ObjectType(
        name: "Auxiliary",
        structuralType: .node,
        components: [
            NameComponent.self,
            FormulaComponent.self,
            PositionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    /// An auxiliary node - containing a constant or a formula.
    ///
    public static let GraphicalFunction = ObjectType(
        name: "GraphicalFunction",
        structuralType: .node,
        components: [
            NameComponent.self,
            PositionComponent.self,
            GraphicalFunctionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
            // TODO: IMPORTANT: Make sure we do not have formula component here or handle the type
        ]
    )
    
    public static let Control = ObjectType(
        name: "Control",
        structuralType: .node,
        components: [
            NameComponent.self,
            ControlComponent.self,
        ]
    )
    public static let Chart = ObjectType(
        name: "Chart",
        structuralType: .node,
        components: [
            NameComponent.self,
            ChartComponent.self,
        ]
    )
    
    public static let Note = ObjectType(
        name: "Note",
        structuralType: .node,
        components: [
            NoteComponent.self,
        ]
    )

    /// Edge from a stock to a flow. Denotes "what the flow drains".
    ///
    /// - SeeAlso: ``FlowsMetamodel/Flow``, ``FlowsMetamodel/Fills-8qqu8``
    ///
    public static let Drains = ObjectType(
        name: "Drains",
        structuralType: .edge,
        components: [
            // None for now
        ],
        abstract: "Edge from a stock node to a flow node, representing what the flow drains."
    )

    /// Edge from a flow to a stock. Denotes "what the flow fills".
    ///
    /// - SeeAlso: ``FlowsMetamodel/Flow``, ``FlowsMetamodel/Drains-38oqw``
    ///
    public static let Fills = ObjectType(
        name: "Fills",
        structuralType: .edge,
        components: [
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
        components: [
            // None for now
        ]
    )
   
    /// Edge between two stocks that are connected through a flow.
    ///
    /// Implicit flow is an edge between two stocks connected by a flow
    /// where one stocks fills the flow and another stock drains the flow.
    ///
    /// ```
    ///              Drains           Fills
    ///    Stock a ==========> Flow =========> Stock b
    ///       |                                  ^
    ///       +----------------------------------+
    ///                   implicit flow
    ///
    /// ```

    /// - Note: This edge is created by the system, not by the user.
    ///
    public static let ImplicitFlow = ObjectType(
        name: "ImplicitFlow",
        structuralType: .edge,
        isSystemOwned: true,
        components: [
            // None for now
        ],
        abstract: "Edge between two stocks."
    )

    public static let ValueBinding = ObjectType(
        name: "ValueBinding",
        structuralType: .edge,
        isSystemOwned: false,
        components: [
            // None for now
        ],
        abstract: "Edge between a control and a value node. The control observes the value after each step."
    )

    public static let ChartSeries = ObjectType(
        // TODO: Origin: Chart, target: Expression
        name: "ChartSeries",
        structuralType: .edge,
        isSystemOwned: false,
        components: [
            // None for now
        ],
        abstract: "Edge between a control and its target."
    )

    // NOTE: If we were able to use Mirror on types, we would not need this
    /// List of object types for the Stock and Flow metamodel.
    ///
    public static let objectTypes: [ObjectType] = [
        Stock,
        Flow,
        Auxiliary,
        GraphicalFunction,
        
        Drains,
        Fills,
        Parameter,
        ImplicitFlow,

        // UI
        Control,
        Chart,
        ChartSeries,
        ValueBinding,
    ] + BasicMetamodel.objectTypes
    
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
    public static let constraints: [Constraint] = [
        Constraint(
            name: "flow_fill_is_stock",
            abstract: """
                      Flow must drain (from) a stock, no other kind of node.
                      """,
            match: EdgePredicate(IsTypePredicate(Fills)),
            requirement: AllSatisfy(
                EdgePredicate(
                    origin: IsTypePredicate(Flow),
                    target: IsTypePredicate(Stock)
                )
            )
        ),
            
        Constraint(
            name: "flow_drain_is_stock",
            abstract: """
                      Flow must fill (into) a stock, no other kind of node.
                      """,
            match: EdgePredicate(IsTypePredicate(Drains)),
            requirement: AllSatisfy(
                EdgePredicate(
                    origin: IsTypePredicate(Stock),
                    target: IsTypePredicate(Flow)
                )
            )
        ),
        
        Constraint(
            name: "one_parameter_for_graphical_function",
            abstract: """
                      Graphical function must not have more than one incoming parameters.
                      """,
            match: IsTypePredicate(GraphicalFunction),
            requirement: UniqueNeighbourRequirement(
                NeighborhoodSelector(
                    predicate: IsTypePredicate(Parameter),
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
            match: EdgePredicate(IsTypePredicate(ValueBinding)),
            requirement: AllSatisfy(
                EdgePredicate(
                    origin: IsTypePredicate(Control),
                    target: HasComponentPredicate(FormulaComponent.self)
                )
            )
        ),
        Constraint(
            name: "chart_series",
            abstract: """
                      Chart series edge must originate in Chart and end in Value node.
                      """,
            match: EdgePredicate(IsTypePredicate(ChartSeries)),
            requirement: AllSatisfy(
                EdgePredicate(
                    origin: IsTypePredicate(Chart),
                    target: HasComponentPredicate(FormulaComponent.self)
                )
            )
        ),
    ]
    
    // MARK: Built-in variables
    // ---------------------------------------------------------------------
    /// Built-in variable reference that represents the simulation time.
    ///
    public static let TimeVariable = BuiltinVariable(
        name: "time",
        abstract: "Current simulation time"
    )

    /// Built-in variable reference that represents the time delta.
    ///
    public static let TimeDeltaVariable = BuiltinVariable(
        name: "time_delta",
        abstract: "Simulation time delta - time between discrete steps of the simulation."
    )
    
    /// List of all built-in variables.
    /// 
    public static let variables: [BuiltinVariable] = [
        TimeVariable,
        TimeDeltaVariable,
    ]

}
