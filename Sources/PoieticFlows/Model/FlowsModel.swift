//
//  Metamodel.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import PoieticCore

/// The metamodel for Stock-and-Flows domain model.
///
/// - SeeAlso: `Metamodel` protocol description for more information and reasons
/// behind this approach of describing the metamodel.
///
class FlowsMetamodel: Metamodel {
    // MARK: Components
    // ---------------------------------------------------------------------

    static let components: [Component.Type] = [
        StockComponent.self,
        FlowComponent.self,
        ExpressionComponent.self,
        PositionComponent.self,
    ]
    
    
    // MARK: Object Types
    // ---------------------------------------------------------------------

    static let Stock = ObjectType(
        name: "Stock",
        structuralType: Node.self,
        components: [
            .defaultValue(ExpressionComponent.self),
            .defaultValue(StockComponent.self),
            // PositionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: Node.self,
        components: [
            .defaultValue(ExpressionComponent.self),
            .defaultValue(FlowComponent.self),
            // PositionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    static let Auxiliary = ObjectType(
        name: "Auxiliary",
        structuralType: Node.self,
        components: [
            .defaultValue(ExpressionComponent.self),
            // PositionComponent.self,
            // DescriptionComponent.self,
            // ErrorComponent.self,
        ]
    )
    
    /// Edge from a stock to a flow. Denotes "what the flow drains".
    ///
    static let Drains = ObjectType(
        name: "Drains",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )

    /// Edge from a flow to a stock. Denotes "what the flow fills".
    ///
    static let Fills = ObjectType(
        name: "Fills",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )
    static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )
    static let ImplicitFlow = ObjectType(
        name: "ImplicitFlow",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )
    
    static let objectTypes: [ObjectType] = [
        Stock,
        Flow,
        Auxiliary,
        
        Drains,
        Fills,
        Parameter,
        ImplicitFlow,
    ]
    
    // MARK: Constraints
    // ---------------------------------------------------------------------
    static let constraints: [any Constraint] = [
        EdgeConstraint(
            name: "flow_fill_is_stock",
            description: """
                         Flow must drain (from) a stock, no other kind of node.
                         """,
            match: EdgeObjectPredicate(
                origin: IsTypePredicate(Stock),
                target: IsTypePredicate(Flow),
                edge: IsTypePredicate(Fills)
            ),
            requirement: RejectAll()
        ),
            
        EdgeConstraint(
            name: "flow_drain_is_stock",
            description: """
                         Flow must fill (into) a stock, no other kind of node.
                         """,
            match: EdgeObjectPredicate(
                origin: IsTypePredicate(Flow),
                target: IsTypePredicate(Stock),
                edge: IsTypePredicate(Drains)
            ),
            requirement: RejectAll()
        ),
    ]

    // MARK: Queries and Predicates
    // ---------------------------------------------------------------------
    
    static let expressionNodes = HasComponentPredicate(ExpressionComponent.self)
    static let flowNodes = IsTypePredicate(Flow)

    static let parameterEdges = IsTypePredicate(Parameter)
    static let incomingParameters = NeighborhoodSelector(
        predicate: parameterEdges,
        direction: .incoming
    )
    
    static let fillsEdge = IsTypePredicate(Fills)
    // TODO: Rename to flowFills to prevent confusion
    /// Selector for an edge originating in a flow and ending in a stock denoting
    /// which stock the flow fills. There must be only one of such edges
    /// originating in a flow.
    ///
    /// Neighbourhood of stocks around the flow.
    ///
    ///     Flow --(Fills)--> Stock
    ///      ^                  ^
    ///      |                  +--- Neighbourhood (only one)
    ///      |
    ///      Node of interest
    ///
    static let fills = NeighborhoodSelector(
        predicate: fillsEdge,
        direction: .outgoing
    )
    /// Selector for edges originating in a flow and ending in a stock denoting
    /// the inflow from multiple flows into a single stock.
    ///
    ///     Flow --(Fills)--> Stock
    ///      ^                  ^
    ///      |                  +--- Node of interest
    ///      |
    ///      Neighbourhood (many)
    ///
    static let inflows = NeighborhoodSelector(
        predicate: fillsEdge,
        direction: .incoming
    )

    static let drainsEdge = IsTypePredicate(Drains)
    // TODO: Rename to flowDrains to prevent confusion
    /// Selector for an edge originating in a stock and ending in a flow denoting
    /// which stock the flow drains. There must be only one of such edges
    /// ending in a flow.
    ///
    /// Neighbourhood of stocks around the flow.
    ///
    ///     Stock --(Drains)--> Flow
    ///      ^                    ^
    ///      |                    +--- Node of interest
    ///      |
    ///      Neighbourhood (only one)
    ///
    ///
    static let drains = NeighborhoodSelector(
        predicate: drainsEdge,
        direction: .incoming
    )
    
    /// Selector for edges originating in a stock and ending in a flow denoting
    /// the outflow from the stock to multiple flows.
    ///
    ///
    ///     Stock --(Drains)--> Flow
    ///      ^                    ^
    ///      |                    +--- Neighbourhood (many)
    ///      |
    ///      Node of interest
    ///
    ///
    static let outflows = NeighborhoodSelector(
        predicate: drainsEdge,
        direction: .outgoing
    )

    static let implicitFlowEdge = IsTypePredicate(ImplicitFlow)
    static let implicitFills = NeighborhoodSelector(
        predicate: implicitFlowEdge,
        direction: .outgoing
    )
    static let implicitDrains = NeighborhoodSelector(
        predicate: implicitFlowEdge,
        direction: .incoming
    )
    
    // MARK: Built-in variables
    // ---------------------------------------------------------------------
    static let TimeVariable = BuiltinVariable(
        name: "time",
        description: "Current simulation time"
    )

    static let TimeDeltaVariable = BuiltinVariable(
        name: "time_delta",
        description: "Simulation time delta - time between discrete steps of the simulation."
    )
    
    static let variables: [BuiltinVariable] = [
        TimeVariable,
        TimeDeltaVariable,
    ]

}
