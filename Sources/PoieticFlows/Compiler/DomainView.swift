//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import PoieticCore

public struct DomainError: Error {
    var issues: [ObjectID:[NodeIssue]]
}

/// Flows domain view on top of a graph.
///
public class DomainView {
    public let graph: Graph
    
    public init(_ graph: Graph) {
        self.graph = graph
    }
    
    /// List of expression nodes in the graph.
    ///
    public var expressionNodes: [Node] {
        graph.selectNodes(FlowsMetamodel.expressionNodes)
    }
    
    /// Collect names of objects.
    ///
    public func collectNames() throws -> [String:ObjectID] {
        // TODO: Rename to "namedNodes"

        var names: [String: [ObjectID]] = [:]
        var issues: [ObjectID: [NodeIssue]] = [:]
        
        for node in expressionNodes {
            let name = node[FormulaComponent.self]!.name
            names[name, default: []].append(node.id)
        }
        var dupes: [String] = []
        var result: [String: ObjectID] = [:]
        
        for (name, ids) in names {
            if ids.count > 1 {
                let issue = NodeIssue.duplicateName(name)
                dupes.append(name)
                for id in ids {
                    issues[id, default: []].append(issue)
                }
            }
            else {
                result[name] = ids[0]
            }
        }
        
        if issues.isEmpty {
            return result
        }
        else {
            throw DomainError(issues: issues)
        }
    }
    
    public func compileExpressions(names: [String:ObjectID]) throws -> [ObjectID:BoundExpression] {
        // TODO: Rename to "boundExpressions"

        var result: [ObjectID:BoundExpression] = [:]
        var issues: [ObjectID: [NodeIssue]] = [:]
        
        for node in expressionNodes {
            let component: FormulaComponent = node[FormulaComponent.self]!
            do {
                let parser = ExpressionParser(string: component.expressionString)
                let unboundExpr = try parser.parse()
                let boundExpr = bind(unboundExpr, names: names)
                result[node.id] = boundExpr
            }
            catch let error as SyntaxError {
                issues[node.id] = [.expressionSyntaxError(error)]
            }
        }
        
        if issues.isEmpty {
            return result
        }
        else {
            throw DomainError(issues: issues)
        }
    }
    
    public func validateInputs(nodeID: ObjectID, required: [String]) -> [NodeIssue] {
        // TODO: Rename to "parameterIssues"

        let incomingParams = graph.hood(nodeID, selector: FlowsMetamodel.incomingParameters)
        let vars: Set<String> = Set(required)
        var incomingNames: Set<String> = Set()
        
        for paramNode in incomingParams.nodes {
            let expr: FormulaComponent = paramNode[FormulaComponent.self]!
            let name = expr.name
            incomingNames.insert(name)
        }
        
        let unknown = vars.subtracting(incomingNames)
        let unused = incomingNames.subtracting(vars)
        
        let unknownIssues = unknown.map {
            NodeIssue.unknownParameter($0)
        }
        let unusedIssues = unused.map {
            NodeIssue.unusedInput($0)
        }
        
        return Array(unknownIssues) + Array(unusedIssues)
    }
    
    /// Sort the nodes based on their parameter dependency.
    ///
    /// The function returns nodes that are sorted in the order of computation.
    /// If the parameter connections are valid and there are no cycles, then
    /// the nodes in the returned list can be safely computed in the order as
    /// returned.
    ///
    /// - Throws: `GraphCycleError` when cycle was detected.
    ///
    public func sortNodes(nodes: [ObjectID]) throws -> [Node] {
        // TODO: Rename to "sortedNodesByParameter"
        
        let edges: [Edge] = graph.selectEdges(FlowsMetamodel.parameterEdges)
        let sorted = try graph.topologicalSort(nodes, edges: edges)
        
        let result: [Node] = sorted.map {
            graph.node($0)!
        }
        
        return result
    }
    
    public func sortedStocksByImplicitFlows(_ nodes: [ObjectID]) throws -> [Node] {
        // TODO: Rename to "sortedNodesByParameter"
        
        let edges: [Edge] = graph.selectEdges(FlowsMetamodel.implicitFlowEdge)
        let sorted = try graph.topologicalSort(nodes, edges: edges)
        
        let result: [Node] = sorted.map {
            graph.node($0)!
        }
        
        return result
    }
    
    public func flowFills(_ flowID: ObjectID) -> ObjectID? {
        let flowNode = graph.node(flowID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(flowNode.type === FlowsMetamodel.Flow)
        
        let hood = graph.hood(flowID, selector: FlowsMetamodel.fills)
        if let node = hood.nodes.first {
            return node.id
        }
        else {
            return nil
        }
    }
    
    public func flowDrains(_ flowID: ObjectID) -> ObjectID? {
        let flowNode = graph.node(flowID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(flowNode.type === FlowsMetamodel.Flow)
        
        let hood = graph.hood(flowID, selector: FlowsMetamodel.drains)
        if let node = hood.nodes.first {
            return node.id
        }
        else {
            return nil
        }
    }
    
    public func stockInflows(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.inflows)
        return hood.nodes.map { $0.id }
    }
    
    public func stockOutflows(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.outflows)
        return hood.nodes.map { $0.id }
    }

    public func implicitFills(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.implicitFills)
        
        return hood.nodes.map { $0.id }
    }

    public func implicitDrains(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.implicitDrains)
        
        return hood.nodes.map { $0.id }
    }
}
/// Bind an expression to a compiled model. Return a bound expression.
///
/// Bound expression is an expression where the variable references are
/// resolved to match their respective nodes.
///
public func bind(_ expression: UnboundExpression,
                 names: [String:ObjectID]) -> BoundExpression {
    var references: [String:BoundVariableReference] = [:]
    for (name, id) in names {
        references[name] = .object(id)
    }
    
    // TODO: Add built-ins here
    // references["time"] = FlowsMetamodel.TimeVariable
    // references["time_delta"] = FlowsMetamodel.TimeDeltaVariable
    
    let boundExpr = expression.bind(variables: references)
    
    return boundExpr
}
