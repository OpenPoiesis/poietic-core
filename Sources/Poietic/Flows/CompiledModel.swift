//
//  CompiledModel.swift
//  
//
//  Created by Stefan Urbanek on 05/06/2022.
//

/// Structure used by the simulator.
///
/// Compiled model is a version of the model that is interpreted by the
/// simulator. It is guaranteed to be consistent.
///
/// - Note: Any inconsistencies in the compiled model encountered by the
///   simulator are considered a programming error. Simulation should not
///   proceed if the compiled model is broken.
///
/// - Note: This is conceptual equivalent to "explain plan" – how the simulation
///   will be carried out.
///
public struct CompiledModel {
    // TODO: Alternative names: ResolvedModel, ExecutableModel
    // TODO: Use some kind of ordered dictionaries where appropriate
    
    /// Map of nodes and their corresponding compiled expressions.
    ///
    let expressions: [ObjectID: BoundExpression]
    
    /// Sorted expression nodes by parameter dependency.
    ///
    /// The nodes are ordered so that nodes that do not require other nodes
    /// to be computed (such as constants) are at the beginning. The nodes
    /// that depend on other nodes by using them as a parameter follow the nodes
    /// they depend on.
    ///
    /// Computing nodes in this order assures that we have all parameters
    /// computed when needed.
    ///
    /// - Note: It is guaranteed that the nodes are ordered. If a cycle was
    ///         present in the model, the compiled model would not have been
    ///         created.
    ///
    let sortedExpressionNodes: [Node]
    
    /// Stocks, by order of computation dependency
    let stocks: [ObjectID]
    let stockComponents: [ObjectID:StockComponent]
    
    /// Auxiliaries required by stocks, by order of dependency
    let auxiliaries: [ObjectID]

    /// All flows in order of computation
    let flows: [ObjectID]
    let flowComponents: [ObjectID:FlowComponent]

    /// Stock -> [Flow]
    let inflows: [ObjectID:[ObjectID]]
    /// Stock -> [Flow]
    // TODO: Sort by priority
    //                 $0[Flow.self]!.priority < $1[Flow.self]!.priority

    let outflows: [ObjectID:[ObjectID]]

//    public init() {
//        expressions = [:]
//        sortedExpressionNodes = []
//
//        auxiliaries = []
//        stocks = []
//        stockComponents = [:]
//        flows = []
//        flowComponents = [:]
//
//        inflows = [:]
//        outflows = [:]
//    }
    
}

