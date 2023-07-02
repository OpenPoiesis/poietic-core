//
//  CompiledModel.swift
//  
//
//  Created by Stefan Urbanek on 05/06/2022.
//

import PoieticCore

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
    
    /// Stocks ordered by the computation (parameter) dependency.
    let stocks: [ObjectID]
    
    /// Extracted stock components from the stock objects.
    let stockComponents: [ObjectID:StockComponent]
    
    /// Auxiliaries required by stocks, by order of dependency.
    let auxiliaries: [ObjectID]

    /// Flows ordered by the computation (parameter) dependency.
    let flows: [ObjectID]

    /// Extracted flow components from the flow objects.
    let flowComponents: [ObjectID:FlowComponent]

    /// Map containing information about which flows fill a stock.
    ///
    /// The key is a stock, the value of the dictionary is a list of flows that
    /// "inflow" into or fill the stock.
    ///
    /// The mapping is expected to have an entry for each stock. For stocks
    /// without inflows the list is going to be empty.
    ///
    let inflows: [ObjectID:[ObjectID]]
    // TODO: Sort by priority
    //                 $0[Flow.self]!.priority < $1[Flow.self]!.priority

    /// Map containing information about which flows drain a stock.
    ///
    /// The key is a stock, the value of the dictionary is a list of flows that
    /// "outflow" from or drain the stock.
    ///
    /// The mapping is expected to have an entry for each stock. For stocks
    /// without inflows the list is going to be empty.
    ///
    let outflows: [ObjectID:[ObjectID]]

    
    public var namedNodes: [String: Node] {
        var result: [String: Node] = [:]
        
        for node in sortedExpressionNodes {
            let expr: FormulaComponent = node[FormulaComponent.self]!
            result[expr.name] = node
        }
        return result
    }

    /// Get expression node with given name.
    public func expressionNode(name: String) -> Node? {
        for node in sortedExpressionNodes {
            let expr: FormulaComponent = node[FormulaComponent.self]!
            if expr.name == name {
                return node
            }
        }
        return nil
    }
}

