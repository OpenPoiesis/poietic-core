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
    
    static let Drains = ObjectType(
        name: "Drains",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )
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
    static let fills = NeighborhoodSelector(
        predicate: fillsEdge,
        direction: .outgoing
    )

    static let drainsEdge = IsTypePredicate(Drains)
    static let drains = NeighborhoodSelector(
        predicate: drainsEdge,
        direction: .incoming
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
