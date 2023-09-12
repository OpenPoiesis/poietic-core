//
//  Compiler.swift
//
//
//  Created by Stefan Urbanek on 21/06/2022.
//

import PoieticCore

/// An object that compiles the model into a ``CompiledModel``.
///
/// We are treating the user's design as a non-linear/graphical
/// programming language. The compiler transforms the design to a form that
/// can be interpreted - simulated.
///
/// The compiler makes sure that the model is valid, references
/// are resolved. It resolves the order in which the nodes are
/// to be evaluated.
///
///
public class Compiler {
    /// The frame containing the design to be compiled.
    ///
    let frame: MutableFrame

    /// Mutable view of the frame as a graph.
    let graph: MutableGraph
    
    /// Flows domain view of the frame.
    let view: StockFlowView

    /// Creates a compiler that will compile within the context of the given
    /// model.
    ///
    public init(frame: MutableFrame) {
        // FIXME: Compiler should get a stable frame, not a mutable frame!
        self.frame = frame
        self.graph = frame.mutableGraph
        self.view = StockFlowView(self.graph)
    }

    /// Compiles the model and returns the compiled version of the model.
    ///
    /// The compilation process is as follows:
    ///
    /// 1. Gather all node names and check for potential duplicates
    /// 2. Compile all formulas (expressions) and bind them with concrete
    ///    objects.
    /// 3. Sort the nodes in the order of computation.
    /// 4. Pre-filter nodes for easier usage by the solver: stocks, flows
    ///    and auxiliaries. All filtered collections stay ordered.
    /// 5. Create implicit flows between stocks and sort stocks in order
    ///    of their dependency.
    /// 6. Finalise the compiled model.
    ///
    /// - Throws: A ``DomainError`` when there are issues with the model.
    /// - Returns: A ``CompiledModel`` that can be used directly by the
    ///   simulator.
    ///
    public func compile() throws -> CompiledModel {
        // FIXME: var nodeIssues: [NodeID:[NodeIssue]] = [:]

        let violations = frame.memory.checkConstraints(frame)
        
        if !violations.isEmpty {
            // TODO: How to handle this here?
            // Note: the compiler should work with stable frame - with
            //       constraints satisfied. Remove this once the previous
            //       sentence statement is true.
            let error = ConstraintViolationError(violations: violations)
            for (obj, errors) in error.prettyDescriptionsByObject {
                for error in errors {
                    print("ERROR: \(obj): \(error)")
                }
            }
            throw ConstraintViolationError(violations: violations)
        }

        // 1. Collect node names
        // -----------------------------------------------------------------
        //
        let nameToObject = try view.namesToObjects()
        let objectToName = view.objectsToNames()

        // 2. Compile computational representations (computations)
        // -----------------------------------------------------------------
        //
        var computations: [ObjectID:ComputationalRepresentation] = [:]

        // 2.1 Compile expressions
        //
        let expressions = try view.boundExpressions(names: nameToObject)
        
        for (id, expression) in expressions {
            computations[id] = .formula(expression)
        }

        // 2.2 Compile graphical functions
        //
        for boundFunction in try view.boundGraphicalFunctions() {
            guard let nodeName = objectToName[boundFunction.functionNodeID] else {
                fatalError("Graphical function node \(boundFunction.functionNodeID) has no name component. Internal hint: Model integrity is not assured.")
            }

            let funcName = "__graphical_\(nodeName)"
            let numericFunc = boundFunction.function.createFunction(name: funcName)

            computations[boundFunction.functionNodeID] = .graphicalFunction(numericFunc, boundFunction.parameterID)
        }
                
        // 3. Sort nodes in order of computation
        // -----------------------------------------------------------------
        //
        let sortedNodes = try view.sortedNodesByParameter(nodes: Array(computations.keys))

        // 4. Filter by node type
        // -----------------------------------------------------------------
        //
        let unsortedStocks = sortedNodes.filter { $0.type === FlowsMetamodel.Stock }
        let flows = sortedNodes.filter { $0.type === FlowsMetamodel.Flow }
        let auxiliaries = sortedNodes.filter {
            $0.type === FlowsMetamodel.Auxiliary
            || $0.type === FlowsMetamodel.GraphicalFunction
        }
        
        // 5. Sort stocks in order of flow dependency
        // -----------------------------------------------------------------
        //
        // This step is needed for proper computation of non-negative stocks

        updateImplicitFlows()
        var stocks: [Node]
        do {
            let unsorted = unsortedStocks.map { $0.id }
            let sorted = try view.sortedStocksByImplicitFlows(unsorted)
            stocks = sorted
        }
        // catch let error as GraphCycleError {
        catch is GraphCycleError {
            // FIXME: Handle the error
            fatalError("Unhandled graph cycle error")
        }
        
        // 6. Value Bindings
        //
        var bindings: [ValueBinding] = []
        for object in frame.filter(type: FlowsMetamodel.ValueBinding) {
            guard let edge = Edge(object) else {
                // This should not happen
                fatalError("A value binding  \(object.id) is not an edge")
            }
            
            let binding = ValueBinding(control: edge.origin, target: edge.target)
            bindings.append(binding)
        }
        
        // Finalize
        // -----------------------------------------------------------------
        //
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
        
        for edge in view.drainsEdges {
            // Drains edge: stock ---> flow
            let stock = edge.origin
            let flow = edge.target
            outflows[stock]!.append(flow)
        }

        // Sort the outflows by priority
        for stock in stocks {
            let sortedOutflows = outflows[stock.id]!.map {
                // 1. Get the priority component
                    let node = graph.node($0)
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
        
        for edge in view.fillsEdges {
            // Fills edge: flow ---> stock
            let flow = edge.origin
            let stock = edge.target
            inflows[stock]!.append(flow)
        }

        return CompiledModel(
            computations: computations,
            sortedExpressionNodes: sortedNodes,
            stocks: stocks.map {$0.id},
            stockComponents: stockComponents,
            auxiliaries: auxiliaries.map {$0.id},
            flows: flows.map {$0.id},
            flowComponents: flowComponents,
            inflows: inflows,
            outflows: outflows,
            valueBindings: bindings
        )
    }

    /// Update edges that denote implicit flows between stocks.
    ///
    /// The created edges are of type ``FlowsMetamodel/ImplicitFlow``.
    ///
    /// The process:
    ///
    /// - create an edge between two stocks that are also connected by
    ///   a flow
    /// - clean-up edges between stocks where is no flow
    ///
    /// - SeeAlso: ``DomainView/implicitFills(_:)``,
    ///   ``DomainView/implicitDrains(_:)``,
    ///   ``DomainView/sortedStocksByImplicitFlows(_:)``
    ///
    public func updateImplicitFlows() {
        var unused: [Edge] = view.implicitFlowEdges
        
        for flow in view.flowNodes {
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
