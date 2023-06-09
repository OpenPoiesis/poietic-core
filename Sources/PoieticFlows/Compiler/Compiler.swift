//
//  Compiler.swift
//
//
//  Created by Stefan Urbanek on 21/06/2022.
//

import PoieticCore

/// An object that compiles the model into a ``CompiledModel``.
///
/// The compiler makes sure that the model is valid, references
/// are resolved. It resolves the order in which the nodes are
/// to be evaluated.
///
public class Compiler {
    // NOTE: This class is intended to synchronise a state between a model and
    //       its compiled counterpart. It is meant to operate incrementally.
    
    /// Reference to the model to be compiled.
    let graph: MutableGraph
    let frame: MutableFrame
    let view: DomainView

    /// Creates a compiler that will compile within the context of the given
    /// model.
    ///
    public init(frame: MutableFrame) {
        self.frame = frame
        self.graph = frame.mutableGraph
        self.view = DomainView(self.graph)
    }

    /// Compiles the model and returns the compiled version of the model.
    ///
    /// The compilation process is as follows:
    ///
    /// 1. Compile every expression node into a `CompiledExpressionNode`. See
    ///    ``Compiler/compile(node:)``
    /// 2. Check constraints using ``Compiler/checkConstraints()``
    /// 3. Topologically sort the expression nodes.
    ///
    /// - Throws: A ``ModelCompilationError`` when there are issues with the model.
    /// - Returns: A ``CompiledModel`` that can be used directly by the
    ///   simulator.
    ///
    public func compile() throws -> CompiledModel {
        // FIXME: var nodeIssues: [NodeID:[NodeIssue]] = [:]

        // 1. Collect node names
        // -----------------------------------------------------------------
        //
        let names = try view.collectNames()

        // 2. Compile expressions
        // -----------------------------------------------------------------
        //
        let expressions = try view.compileExpressions(names: names)
        
        // 3. Sort nodes in order of computation
        // -----------------------------------------------------------------
        //
        let sortedNodes = try view.sortNodes(nodes: Array(expressions.keys))
        
        // 4. Finalise and collect issues
        // -----------------------------------------------------------------
        //
        let stocks = sortedNodes.filter { $0.type === FlowsMetamodel.Stock }
        let flows = sortedNodes.filter { $0.type === FlowsMetamodel.Flow }
        let auxiliaries = sortedNodes.filter { $0.type === FlowsMetamodel.Auxiliary }

        var stockComponents: [ObjectID:StockComponent] = [:]
        for stock in stocks {
            stockComponents[stock.id] = stock[StockComponent.self]!
        }

        var flowComponents: [ObjectID:FlowComponent] = [:]
        for flow in flows {
            flowComponents[flow.id] = flow[FlowComponent.self]!
        }
        
        var outflows: [ObjectID: [ObjectID]] = [:]
        var inflows: [ObjectID: [ObjectID]] = [:]
        
        // Create an empty list of each stock. The map is expected to contain an
        // entry for each stock.
        for stock in stocks {
            outflows[stock.id] = []
            inflows[stock.id] = []
        }
        
        for edge in graph.selectEdges(FlowsMetamodel.drainsEdge) {
            // Drains edge: stock ---> flow
            let stock = edge.origin
            let flow = edge.target
            outflows[stock]!.append(flow)
        }

        // Sort the outflows by priority
        for stock in stocks {
            let sortedOutflows = outflows[stock.id]!.map {
                // 1. Get the priority component
                    let node = graph.node($0)!
                    let component: FlowComponent = node[FlowComponent.self]!
                    return (id: $0, priority: component.priority)
                }
                // Sort by priority
                .sorted { (lhs, rhs) in
                    return lhs.priority < rhs.priority
                }
                // Get what we need: the node id
                .map { $0.id }
            outflows[stock.id] = sortedOutflows
        }
        
        for edge in graph.selectEdges(FlowsMetamodel.fillsEdge) {
            // Fills edge: flow ---> stock
            let flow = edge.origin
            let stock = edge.target
            inflows[stock]!.append(flow)
        }

        return CompiledModel(
            expressions: expressions,
            sortedExpressionNodes: sortedNodes,
            stocks: stocks.map {$0.id},
            stockComponents: stockComponents,
            auxiliaries: auxiliaries.map {$0.id},
            flows: flows.map {$0.id},
            flowComponents: flowComponents,
            inflows: inflows,
            outflows: outflows
        )
    }

    /// Update edges that denote implicit flows between stocks. The edges
    /// are created in the simulator dimension (``Metamodel/SimulationDimensionTag``)
    ///
    /// The process:
    ///
    /// - create an edge between two stocks that are also connected by
    ///   a flow
    /// - clean-up edges between stocks where is no flow
    ///
    public func updateImplicitFlows() {
        var unused: [Edge] = graph.selectEdges(FlowsMetamodel.implicitFlowEdge)
        
        for flow in graph.selectNodes(FlowsMetamodel.flowNodes) {
            guard let fills = view.flowFills(flow.id) else {
                continue
            }
            guard let drains = view.flowDrains(flow.id) else {
                continue
            }
            
            let index = unused.firstIndex { edge in
                edge.origin == drains && edge.target == fills
            }
            if let index {
                // Keep the existing, and prevent from deletion later.
                unused.remove(at: index)
                continue
            }
            
            graph.createEdge(FlowsMetamodel.ImplicitFlow,
                             origin: drains,
                             target: fills,
                             components: [])
        }
        
        for edge in unused {
            graph.remove(edge: edge.id)
        }
    }
}
