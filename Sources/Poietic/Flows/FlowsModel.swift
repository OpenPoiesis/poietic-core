//
//  Metamodel.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

/// Protocol for meta–models – models describing problem domain models.
///
/// The metamodel is the ultimate source of truth for the model domain and
/// should contain all named concepts that can be described declaratively. The
/// main components of the metamodel are:
///
/// - Object types – list of types of objects that are allowed for the domain
/// - Components - list of components that can be assigned to the objects
/// - Queries - list of predicates and queries to provide domain specific view
///   of the object memory and of the graph
///
/// Reasons for this approach:
///
/// - one source of truth
/// - abstraction from persistence, inspection (UI), scripting
/// - transparency and audit-ability of the domain model
/// - reflection
/// - fair compromise between model DSL and native programming language, while
///   providing some possibility of accessing some of the meta-model components
///   through the native programming language identifiers
/// - potentially, in the far future, the metamodel or its parts can be compiled
///   for better performance (which is out of scope at this moment)
///
/// The major use-cases of the reflection:
///
/// - documentation
/// - provide information through tooling to the user about what can be created,
///   used, inspected
/// - there are going to be multiple versions of the toolkit in the wild, users
///   can investigate the capabilities of their installed version of the toolkit
///
protocol Metamodel: AnyObject {
    /// List of components that are available within the domain described by
    /// this metamodel.
    static var components: [Component.Type] { get }
    
    /// List of object types allowed in the model.
    ///
    static var objectTypes: [ObjectType] { get }
    
    static var variables: [BuiltinVariable] { get }
}


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
