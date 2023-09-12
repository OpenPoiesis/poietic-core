//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import PoieticCore


public enum ParameterStatus:Equatable {
    case missing
    case unused(node: ObjectID, edge: ObjectID)
    case used(node: ObjectID, edge: ObjectID)
}

/// A type representing a required para
public struct ParameterOutlet: Equatable, CustomStringConvertible, Hashable {
    // TODO: Add "required" (see below). For now it is just a name wrapper.
    /// Name of the parameter.
    ///
    /// If the name is set, then one of the incoming parameters must have the
    /// name specified. Named parameters are used in formulas.
    ///
    /// If the name is `nil` then the incoming parameter might be of any name.
    /// Unnamed parameters are used for example in graphical functions.
    ///
    public let name: String?
    
    // Specify whether the parameter is required or not.
    //
    // public let required: Bool
    
    public var description: String {
        if let name {
            "\(name)"
        }
        else {
            "(unnamed)"
        }
    }
}


/// A structure representing a concrete instance of a graphical function
/// in the context of a graph.
public struct BoundGraphicalFunction {
    /// ID of a node where the function is defined
    public let functionNodeID: ObjectID
    /// The function object itself
    public let function: GraphicalFunction
    /// ID of a node that is a parameter for the function.
    public let parameterID: ObjectID
}


/// View of Stock-and-Flow domain-specific aspects of the design.
///
/// The domain view provides higher level view of the design through higher
/// level concepts as defined in the ``FlowsMetamodel``.
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
    public func namesToObjects() throws -> [String:ObjectID] {
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
    public func objectsToNames() -> [ObjectID: String] {
        var result: [ObjectID: String] = [:]
        for node in namedNodes {
            let name = node[NameComponent.self]!.name
            result[node.id] = name
        }
        return result
    }

    
    /// Return a dictionary of bound expressions.
    ///
    /// For each node with an arithmetic expression the expression is parsed
    /// from a text into an internal representation. The variable and function
    /// names are resolved to point to actual entities and a new bound
    /// expression is formed.
    ///
    /// - Parameters:
    ///     - names: mapping of variable names to their corresponding objects.
    ///
    /// - Returns: A dictionary where the keys are expression node IDs and values
    ///   are compiled BoundExpressions.
    ///
    /// - Throws: ``DomainError`` with ``NodeIssue/expressionSyntaxError(_:)`` for each node
    ///   which has a syntax error in the expression.
    ///
    public func boundExpressions(names: [String:ObjectID]) throws -> [ObjectID:BoundExpression] {
        // TODO: Rename to "boundExpressions"

        var result: [ObjectID:BoundExpression] = [:]
        var issues: [ObjectID: [NodeIssue]] = [:]
       
        var references: [String:BoundVariableReference] = [:]
        for (name, id) in names {
            references[name] = .object(id)
        }
        
        for variable in FlowsMetamodel.variables {
            references[variable.name] = .builtin(variable)
        }
        
        // FIXME: This is a remnant after expression binding refactoring.
        var functions: [String: any FunctionProtocol] = [:]
        
        for function in AllBuiltinFunctions {
            functions[function.name] = function
        }
        
        for node in expressionNodes {
            let unboundExpression: UnboundExpression
            do {
                unboundExpression =  try node.parsedExpression()!
            }
            catch let error as ExpressionSyntaxError {
                issues[node.id] = [.expressionSyntaxError(error)]
                continue
            }
            let required: [String] = unboundExpression.allVariables.filter {
                // Filter out built-in variables.
                !FlowsMetamodel.variableNames.contains($0)
            }
            // TODO: Move this outside of this method. This is not required for binding
            let inputIssues = validateParameters(node.id, required: required)

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
   
    public func boundGraphicalFunctions() throws -> [BoundGraphicalFunction] {
        var results: [BoundGraphicalFunction] = []
        var error = DomainError()
        
        for node in graphicalFunctionNodes {
            let hood = graph.hood(node.id, selector: FlowsMetamodel.incomingParameters)
            guard let parameterNode = hood.nodes.first else {
                // FIXME: This must be an exception
                error.append(NodeIssue.missingGraphicalFunctionParameter, for: node.id)
                continue
            }
            let component: GraphicalFunctionComponent = node[GraphicalFunctionComponent.self]!

            results.append(BoundGraphicalFunction(functionNodeID: node.id,
                                                  function: component.function,
                                                  parameterID: parameterNode.id))
        }
        if error.isEmpty {
            return results
        }
        else {
            throw error
        }
    }

    
    /// Validates parameter  of a node.
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
    public func validateParameters(_ nodeID: ObjectID, required: [String]) -> [NodeIssue] {
        let parameters = self.parameters(nodeID, required: required)
        var issues: [NodeIssue] = []
        
        for (name, status) in parameters {
            switch status {
            case .used: continue
            case .unused:
                issues.append(.unusedInput(name))
            case .missing:
                issues.append(.unknownParameter(name))
            }
        }
        
        return issues
    }
    
    // FIXME: This is expensive - parsing expression every single time.
    public func parameterOutlets(_ nodeID: ObjectID) -> [ParameterOutlet] {
        let node = graph.node(nodeID)
        var outlets: [ParameterOutlet] = []
        if let expression = try? node.parsedExpression() {
            let vars: Set<String> = Set(expression.allVariables)
            outlets += vars.map { ParameterOutlet(name: $0) }
        }
        
        if node[GraphicalFunctionComponent.self] != nil {
            outlets.append(ParameterOutlet(name: nil))
        }
        
        return outlets
    }
    
    // TODO: Remove the `required` and compute here. Expensive, but useful for the caller.
    // TODO: The `required` should belong to the node itself.
    // TODO: Rename to formulaParameters as this makes sense for formulas only
    public func parameters(_ nodeID: ObjectID,
                           required: [String]) -> [String:ParameterStatus] {
        let incomingHood = graph.hood(nodeID, selector: FlowsMetamodel.incomingParameters)
        var unseen: Set<String> = Set(required)
        var result: [String: ParameterStatus] = [:]

        for edge in incomingHood.edges {
            let node = graph.node(edge.origin)
            let name = node.name!
            if unseen.contains(name) {
                result[name] = .used(node: node.id, edge: edge.id)
                unseen.remove(name)
            }
            else {
                result[name] = .unused(node: node.id, edge: edge.id)
            }
        }
        
        for name in unseen {
            result[name] = .missing
        }

        return result
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
            graph.node($0)
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
            graph.node($0)
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
        let flowNode = graph.node(flowID)
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
        let flowNode = graph.node(flowID)
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
        let stockNode = graph.node(stockID)
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
        let stockNode = graph.node(stockID)
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
    /// - Precondition: `stockID` must be an ID of a node that is a stock.
    ///
    public func implicitFills(_ stockID: ObjectID) -> [ObjectID] {
        let stockNode = graph.node(stockID)
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
        let stockNode = graph.node(stockID)
        // TODO: Do we need to check it here? We assume model is valid.
        precondition(stockNode.type === FlowsMetamodel.Stock)
        
        let hood = graph.hood(stockID, selector: FlowsMetamodel.implicitDrains)
        
        return hood.nodes.map { $0.id }
    }
}
