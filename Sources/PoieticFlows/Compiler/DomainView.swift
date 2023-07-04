//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import PoieticCore

/// Flows domain view on top of a graph.
///
public class DomainView {
    /// Graph that the view projects.
    ///
    public let graph: Graph
    
    /// Create a new view on top of a graph.
    ///
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
    /// - Returns: A dictionary where keys are object names and values are
    ///   object IDs.
    /// - Throws: ``DomainError`` with ``NodeIssue.duplicateName`` for each
    ///   node and name that has a duplicate name.
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
    
    /// Compiles all arithmetic expressions of all expression nodes.
    ///
    /// - Returns: A dictionary where the keys are expression node IDs and values
    ///   are compiled ``BoundExpression``s.
    /// - Throws: ``DomainError`` with ``NodeIssue.syntaxError`` for each node
    ///   which has a syntax error in the expression.
    ///
    public func compileExpressions(names: [String:ObjectID]) throws -> [ObjectID:BoundExpression] {
        // TODO: Rename to "boundExpressions"

        var result: [ObjectID:BoundExpression] = [:]
        var issues: [ObjectID: [NodeIssue]] = [:]
        
        for node in expressionNodes {
            let component: FormulaComponent = node[FormulaComponent.self]!
            let unboundExpression: UnboundExpression
            do {
                let parser = ExpressionParser(string: component.expressionString)
                unboundExpression = try parser.parse()
            }
            catch let error as SyntaxError {
                issues[node.id] = [.expressionSyntaxError(error)]
                continue
            }
            let required: [String] = unboundExpression.allVariables
            let inputIssues = validateInputs(nodeID: node.id, required: required)

            if !inputIssues.isEmpty {
                issues[node.id] = inputIssues
                continue
            }

            let boundExpr = bind(unboundExpression, names: names)
            result[node.id] = boundExpr
        }
        
        if issues.isEmpty {
            return result
        }
        else {
            throw DomainError(issues: issues)
        }
    }
    
    /// Validates inputs of an object with id ``nodeID``.
    ///
    /// The method checks whether the following two requirements are met:
    ///
    /// - node using a parameter name in an expression (in the ``required`` list)
    ///   must have a ``FlowsMetamodel.Parameter`` edge from the parameter node
    ///   with given name.
    /// - node must _not_ have a ``FlowsMetamodel.Parameter``connection from
    ///   a node if the expression is not referring to that node.
    ///
    /// If any of the two requirements are not met, then a corresponding
    /// type of ``NodeIssue`` is added to the list of issues.
    ///
    /// - Parameters:
    ///     - nodeID: ID of a node to be validated for inputs
    ///     - required: List of names (of nodes) that are required for the node
    ///       with id ``nodeID``.
    ///
    /// - Returns: List of issues that the node with ID ``nodeID`` caused. The
    ///   issues can be either ``NodeIssue.unknownParameter`` or
    ///   ``NodeIssue.unusedInput``.
    ///   
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
