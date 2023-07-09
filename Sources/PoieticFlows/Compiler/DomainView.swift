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
    
    // TODO: Use component filter directly here
    /// List of expression nodes in the graph.
    ///
    public var expressionNodes: [Node] {
        graph.selectNodes(FlowsMetamodel.expressionNodes)
    }
    
    public var graphicalFunctionNodes: [Node] {
        graph.selectNodes(FlowsMetamodel.graphicalFunctionNodes)
    }

    public var namedNodes: [Node] {
        graph.selectNodes(FlowsMetamodel.namedNodes)
    }

    
    /// Collect names of objects.
    ///
    /// - Returns: A dictionary where keys are object names and values are
    ///   object IDs.
    /// - Throws: ``DomainError`` with ``NodeIssue/duplicateName(_:)`` for each
    ///   node and name that has a duplicate name.
    ///
    public func nameToObject() throws -> [String:ObjectID] {
        var names: [String: [ObjectID]] = [:]
        var issues: [ObjectID: [NodeIssue]] = [:]
        
        for node in namedNodes {
            let name = node[NameComponent.self]!.name
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

    /// Collect names of objects.
    ///
    /// - Note: The mapping might contain duplicate names. This function
    ///   does not check for duplicity, just collects all the names.
    ///
    /// - Returns: A dictionary where keys are object IDs and values are
    ///   object names.
    ///
    public func objectToName() -> [ObjectID: String] {
        var result: [ObjectID: String] = [:]
        for node in namedNodes {
            let name = node[NameComponent.self]!.name
            result[node.id] = name
        }
        return result
    }

    
    /// Compiles all arithmetic expressions of all expression nodes.
    ///
    /// - Returns: A dictionary where the keys are expression node IDs and values
    ///   are compiled BoundExpressions.
    /// - Throws: ``DomainError`` with ``NodeIssue/expressionSyntaxError(_:)`` for each node
    ///   which has a syntax error in the expression.
    ///
    public func compileExpressions(names: [String:ObjectID]) throws -> [ObjectID:BoundExpression] {
        // TODO: Rename to "boundExpressions"

        var result: [ObjectID:BoundExpression] = [:]
        var issues: [ObjectID: [NodeIssue]] = [:]
       
        var references: [String:BoundVariableReference] = [:]
        for (name, id) in names {
            references[name] = .object(id)
        }
        // TODO: Add built-ins here
        references["time"] = .builtin(FlowsMetamodel.TimeVariable)
        references["time_delta"] = .builtin(FlowsMetamodel.TimeDeltaVariable)
        
        // FIXME: This is a remnant after expression binding refactoring.
        var functions: [String: any FunctionProtocol] = [:]
        
        for function in AllBuiltinFunctions {
            functions[function.name] = function
        }
        
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
            let required: [String] = unboundExpression.allVariables.filter {
                // Filter out built-in variables.
                !FlowsMetamodel.variableNames.contains($0)
            }
            let inputIssues = validateInputs(nodeID: node.id, required: required)

            if !inputIssues.isEmpty {
                issues[node.id] = inputIssues
                continue
            }

            // TODO: Handle all expression errors here
            let boundExpr = try bindExpression(unboundExpression,
                                               variables: references,
                                               functions: functions)
            result[node.id] = boundExpr
        }
        
        if issues.isEmpty {
            return result
        }
        else {
            throw DomainError(issues: issues)
        }
    }
    
    public func graphicalFunctions() throws -> [ObjectID:GraphicalFunction] {
        var result: [ObjectID:GraphicalFunction] = [:]
        
        for node in graphicalFunctionNodes {
            // FIXME: This is a late-night sketch implementation, GFComponent + GF should be merged
            let component: GraphicalFunctionComponent = node[GraphicalFunctionComponent.self]!
            let gf = GraphicalFunction(points: component.points)
            result[node.id] = gf
        }
        
        return result
    }

    
    /// Validates inputs of an object with a given ID.
    ///
    /// The method checks whether the following two requirements are met:
    ///
    /// - node using a parameter name in an expression (in the `required` list)
    ///   must have a ``FlowsMetamodel/Parameter`` edge from the parameter node
    ///   with given name.
    /// - node must _not_ have a ``FlowsMetamodel/Parameter``connection from
    ///   a node if the expression is not referring to that node.
    ///
    /// If any of the two requirements are not met, then a corresponding
    /// type of ``NodeIssue`` is added to the list of issues.
    ///
    /// - Parameters:
    ///     - nodeID: ID of a node to be validated for inputs
    ///     - required: List of names (of nodes) that are required for the node
    ///       with id `nodeID`.
    ///
    /// - Returns: List of issues that the node with ID `nodeID` caused. The
    ///   issues can be either ``NodeIssue/unknownParameter(_:)`` or
    ///   ``NodeIssue/unusedInput(_:)``.
    ///
    public func validateInputs(nodeID: ObjectID, required: [String]) -> [NodeIssue] {
        // TODO: Rename to "parameterIssues"

        let incomingParams = graph.hood(nodeID, selector: FlowsMetamodel.incomingParameters)
        let vars: Set<String> = Set(required)
        var incomingNames: Set<String> = Set()
        
        for paramNode in incomingParams.nodes {
            let comp: NameComponent = paramNode[NameComponent.self]!
            let name = comp.name
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
    /// - Throws: ``GraphCycleError`` when cycle was detected.
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
    
    /// Sort given list of stocks by the order of their implicit flows.
    ///
    /// Imagine that we replace the flow nodes with a direct edge between
    /// the stocks that the flow connects. The drained stock comes before the
    /// filled stock.
    ///
    /// - SeeAlso: ``implicitFills(_:)``,
    ///   ``implicitDrains(_:)``,
    ///   ``Compiler/updateImplicitFlows()``
    public func sortedStocksByImplicitFlows(_ nodes: [ObjectID]) throws -> [Node] {
        // TODO: Rename to "sortedNodesByParameter"
        
        let edges: [Edge] = graph.selectEdges(FlowsMetamodel.implicitFlowEdge)
        let sorted = try graph.topologicalSort(nodes, edges: edges)
        
        let result: [Node] = sorted.map {
            graph.node($0)!
        }
        
        return result
    }
    
    /// Get a node that the given flow fills.
    ///
    /// The flow fills a node, usually a stock, if there is an edge
    /// from the flow node to the node being filled.
    ///
    /// - Returns: ID of the node being filled, or `nil` if there is no
    ///   fill edge outgoing from the flow.
    /// - Precondition: The object with the ID `flowID` must be a flow
    /// (``FlowsMetamodel/Flow``)
    ///
    /// - SeeAlso: ``flowDrains(_:)``,
    ///
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
    
    /// Get a node that the given flow drains.
    ///
    /// The flow drains a node, usually a stock, if there is an edge
    /// from the drained node to the flow node.
    ///
    /// - Returns: ID of the node being drained, or `nil` if there is no
    ///   drain edge incoming to the flow.
    /// - Precondition: The object with the ID `flowID` must be a flow
    /// (``FlowsMetamodel/Flow``)
    ///
    /// - SeeAlso: ``flowDrains(_:)``,
    ///
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
    
    /// Return a list of flows that fill a stock.
    ///
    /// Flow fills a stock if there is an edge of type ``FlowsMetamodel/Fills``
    /// that originates in the flow and ends in the stock.
    ///
    /// - Parameters:
    ///     - stockID: an ID of a node that must be a stock
    ///
    /// - Returns: List of object IDs of flow nodes that fill the
    ///   stock.
    ///
    /// - Precondition: `stockID` must be an ID of a node that is a stock.
    ///
    public func stockInflows(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.inflows)
        return hood.nodes.map { $0.id }
    }
    
    /// Return a list of flows that drain a stock.
    ///
    /// A stock outflows are all flow nodes where there is an edge of type
    /// ``FlowsMetamodel/Drains`` that originates in the stock and ends in
    /// the flow.
    ///
    /// - Parameters:
    ///     - stockID: an ID of a node that must be a stock
    ///
    /// - Returns: List of object IDs of flow nodes that drain the
    ///   stock.
    ///
    /// - Precondition: `stockID` must be an ID of a node that is a stock.
    ///
    public func stockOutflows(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.outflows)
        return hood.nodes.map { $0.id }
    }

    /// Return a list of stock nodes that the given stock fills.
    ///
    /// Stock fills another stock if there exist a flow node in between
    /// the two stocks and the flow drains stock `stockID`.
    ///
    /// In the following example, the returned list of stocks for the stock
    /// `a` would be `[b]`.
    ///
    /// ```
    ///              Drains           Fills
    ///    Stock a ----------> Flow ---------> Stock b
    ///
    /// ```
    ///
    /// - Precondition: ``stockID`` must be an ID of a node that is a stock.
    ///
    public func implicitFills(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.implicitFills)
        
        return hood.nodes.map { $0.id }
    }

    /// Return a list of stock nodes that the given stock drains.
    ///
    /// Stock drains another stock if there exist a flow node in between
    /// the two stocks and the flow fills stock `stockID`
    ///
    /// In the following example, the returned list of stocks for the stock
    /// `b` would be `[a]`.
    ///
    /// ```
    ///              Drains           Fills
    ///    Stock a ----------> Flow ---------> Stock b
    ///
    /// ```
    ///
    /// - Precondition: `stockID` must be an ID of a node that is a stock.
    ///
    public func implicitDrains(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)!
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.implicitDrains)
        
        return hood.nodes.map { $0.id }
    }
}
