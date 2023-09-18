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

    // Compiler State
    // -----------------------------------------------------------------
    /// All nodes that are participating in the simulation, sorted by their
    /// computational dependency.
    ///
    /// Any computation can be safely carried out using the order in this list.
    /// That is, when computing in order, the later nodes already have required
    /// values computed.
    ///
    public private(set) var orderedSimulationNodes: [Node]

    /// Mapping between an object ID and object's name.
    ///
    /// Only simulation nodes are included in the mapping.
    ///
    public private(set) var objectToName: [ObjectID: String]

    /// Mapping between an object name and it's ID.
    ///
    /// When this mapping is populated, we are already guaranteed that there are
    /// no duplicate names of simulation nodes.
    ///
    /// Only simulation nodes are included in the mapping.
    ///
    public private(set) var nameToObject: [String: ObjectID]
    
    /// List of built-in variable names, fetched from the metamodel.
    ///
    /// Used in binding of arithmetic expressions.
    var builtinVariableNames: [String]

    /// List of built-in functions.
    ///
    /// Used in binding of arithmetic expressions.
    var functions: [String: any FunctionProtocol]

    /// Mapping between a variable name and a bound variable reference.
    ///
    /// Used in binding of arithmetic expressions.
    var namedReferences: [String:BoundVariableReference]
    
    /// Mapping between object ID and index of its corresponding simulation
    /// variable.
    ///
    /// Used in compilation of simulation nodes.
    ///
    public private(set) var objectToIndex: [ObjectID: Int]
    
    // Result of the compilation
    /// List of simulation variables. Part of the simulation result.
    ///
    /// This list is the core list of the compiled simulation. It contains all
    /// variables that will be simulated in the order of their computational
    /// dependencies.
    ///
    /// The ``BoundVariableReference.index`` in the ``BoundExpression`` refers
    /// to a variable in this list if the ``VariableReference`` represents an
    /// object.
    ///
    public private(set) var simulationVariables: [SimulationVariable]

    /// List of built-in variables used in the simulation.
    ///
    /// The ``BoundVariableReference.index`` in the ``BoundExpression`` refers
    /// to a built-in variable in this list if the ``VariableReference`` is a
    /// built-in.
    ///
    public private(set) var builtinVariables: [BuiltinVariable]
    /// Creates a compiler that will compile within the context of the given
    /// model.
    ///
    public init(frame: MutableFrame) {
        // FIXME: [IMPORTANT] Compiler should get a stable frame, not a mutable frame!
        self.frame = frame
        self.graph = frame.mutableGraph
        self.view = StockFlowView(self.graph)
        
        // Components of the compiled model
        builtinVariables = []
        simulationVariables = []

        // Intermediated variables and mappigns used for compilation
        nameToObject = [:]
        objectToName = [:]
        objectToIndex = [:]
        orderedSimulationNodes = []

        // Variables for arithmetic expression binding
        builtinVariableNames = []
        functions = [:]
        namedReferences = [:]
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
        
        // 0. Prepare from metamodel
        //
        for function in AllBuiltinFunctions {
            functions[function.name] = function
        }
        builtinVariableNames = FlowsMetamodel.variables.map { $0.name }

        // 1. Collect simulation nodes
        // -----------------------------------------------------------------
        //
        
        // 2. Validate names and create a name map.
        // -----------------------------------------------------------------
        //
        try prepareNodes()

        // 4. Collect state and built-in variable references.
        // -----------------------------------------------------------------
        //
        collectVariableReferences()
        
        // 5. Compile computational representations (computations)
        // -----------------------------------------------------------------
        //
        var issues: [ObjectID: [NodeIssue]] = [:]
        var computations: [ObjectID:ComputationalRepresentation] = [:]
        
        for node in orderedSimulationNodes {
            do {
                let rep = try compile(node)
                computations[node.id] = rep
            }
            catch let error as NodeIssueList {
                // Thrown in parsedExpression()
                issues[node.id, default: []].append(contentsOf: error.issues)
                continue
            }
        }
        
        guard issues.isEmpty else {
            throw DomainError(issues: issues)
        }
        
        for (index, node) in orderedSimulationNodes.enumerated() {
            let variable = SimulationVariable(
                id: node.id,
                index: index,
                computation: computations[node.id]!,
                name: objectToName[node.id]!
            )
            simulationVariables.append(variable)
        }

        // 6. Filter by node type
        // -----------------------------------------------------------------
        //
        var unsortedStocks: [Node] = []
        var flows: [CompiledFlow] = []
        var auxiliaries: [CompiledVariable] = []
        
        for (index, node) in orderedSimulationNodes.enumerated() {
            if node.type === FlowsMetamodel.Stock {
                unsortedStocks.append(node)
            }
            else if node.type === FlowsMetamodel.Flow {
                let component: FlowComponent = node[FlowComponent.self]!
                let compiled = CompiledFlow(id: node.id,
                                            index: index,
                                            component: component)
                flows.append(compiled)
            }
            else if node.type === FlowsMetamodel.Auxiliary
                        || node.type === FlowsMetamodel.GraphicalFunction {
                let compiled = CompiledVariable(id: node.id, index: index)
                auxiliaries.append(compiled)
            }
            else {
                fatalError("Unknown simulation node type: \(node.type)")
            }
        }
        
        // 7. Sort stocks in order of flow dependency
        // -----------------------------------------------------------------
        //
        // This step is needed for proper computation of non-negative stocks

        updateImplicitFlows()
        let sortedStocks: [Node]
        do {
            let unsorted = unsortedStocks.map { $0.id }
            sortedStocks = try view.sortedStocksByImplicitFlows(unsorted)
            
        }
        // catch let error as GraphCycleError {
        catch is GraphCycleError {
            // FIXME: Handle the error
            fatalError("Unhandled graph cycle error")
        }
        
        let compiledStocks = try compile(stocks: sortedStocks)
        
        // 6. Value Bindings
        //
        var bindings: [CompiledControlBinding] = []
        for object in frame.filter(type: FlowsMetamodel.ValueBinding) {
            guard let edge = Edge(object) else {
                // This should not happen
                fatalError("A value binding  \(object.id) is not an edge")
            }
            
            let binding = CompiledControlBinding(control: edge.origin,
                                              variableIndex: variableIndex(edge.target))
            bindings.append(binding)
        }
        
        // Finalize
        // -----------------------------------------------------------------
        //
        let result = CompiledModel(
            builtinVariables: builtinVariables,
            simulationVariables: simulationVariables,
            stocks: compiledStocks,
            flows: flows,
            auxiliaries: auxiliaries,
            valueBindings: bindings
        )
        
        return result
    }

    /// Prepare simulation nodes by gathering them from the design creating
    /// name maps.
    ///
    /// This function collects simulation nodes, sorts them by the order
    /// of their computational dependency and creates a map between object names
    /// and their identities.
    ///
    /// The nodes collected are all nodes that will be participating in the
    /// simulation, such as stocks, flows or graph functions.
    ///
    /// Populated variables:
    ///
    /// - ``Compiler/objectToName``
    /// - ``Compiler/orderedSimulationNodes``
    /// - ``Compiler/nameToObject``
    ///
    /// - Throws: ``DomainError`` with ``NodeIssue/duplicateName(_:)`` for each
    ///   object and name that has a duplicate name.
    ///
    public func prepareNodes() throws {
        var issues: [ObjectID: [NodeIssue]] = [:]

        // 1. Gather all simulation nodes and prepare an ID to name map
        // -----------------------------------------------------------------
        var unsortedNodes: [ObjectID] = []
        for node in view.simulationNodes {
            unsortedNodes.append(node.id)
            self.objectToName[node.id] = node.name!
        }

        // 2. Sort nodes in order of computation
        // -----------------------------------------------------------------
        // All the nodes present in this list will form a simulation state.
        // Indices in this vector will be the indices used through out the
        // simulation.
        //
        do {
            self.orderedSimulationNodes = try view.sortedNodesByParameter(unsortedNodes)
        }
        catch let error as GraphCycleError {
            // FIXME: Handle this.
            fatalError("Unhandled graph cycle error: \(error). (Not implemented.)")
        }

        var nameToObject: [String: ObjectID] = [:]

        // 3. Validate names and create a name map.
        // -----------------------------------------------------------------
        // Collect all name duplicates so we can report them together and
        // not to fail on the first one. More pleasant to the user.
        var homonyms: [String: [ObjectID]] = [:]
        
        for (id, name) in objectToName {
            if let existing = nameToObject[name] {
                if homonyms[name] == nil {
                    homonyms[name] = [existing, id]
                }
                else {
                    homonyms[name]!.append(id)
                }
            }
            else {
                nameToObject[name] = id
                objectToName[id] = name
            }
        }
       
        // 4 Report the duplicates, if any
        // -----------------------------------------------------------------
        //
        var dupes: [String] = []

        for (name, ids) in homonyms {
            precondition(ids.count > 1, "Sanity check failed: Homonyms must have more than one item.")

            let issue = NodeIssue.duplicateName(name)
            dupes.append(name)
            for id in ids {
                issues[id, default: []].append(issue)
            }
        }

        guard issues.isEmpty else {
            throw DomainError(issues: issues)
        }
        
        self.nameToObject = nameToObject
    }
    
    /// Collect all simulation variables and built-in variables.
    ///
    /// The function produces two outputs into the compiler:
    ///
    /// - list of built-in variables
    /// - a mapping between a name and a variable
    ///
    public func collectVariableReferences() {
        var builtinVariables: [BuiltinVariable] = []
        var namedReferences: [String:BoundVariableReference] = [:]
        var builtinVariableNames: [String] = []

        // Collect simulation nodes
        //
        for (index, node) in orderedSimulationNodes.enumerated() {
            let variable = VariableReference.object(node.id)
            let ref = BoundVariableReference(variable: variable, index: index)
            let name = objectToName[node.id]!
            namedReferences[name] = ref
            objectToIndex[node.id] = index
        }
        
        // Collect builtin variables.
        //
        for (index, builtin) in FlowsMetamodel.variables.enumerated() {
            builtinVariables.append(builtin)
            let variable = VariableReference.builtin(builtin)
            let ref = BoundVariableReference(variable: variable, index: index)
            namedReferences[builtin.name] = ref
            builtinVariableNames.append(builtin.name)
        }

        self.namedReferences = namedReferences
        self.builtinVariables = builtinVariables
        self.builtinVariableNames = builtinVariableNames
    }
   
    /// Get an index of a simulation variable that represents a node with given
    /// ID.
    ///
    /// - Precondition: Object with given ID must have a corresponding
    ///   simulation variable.
    ///
    public func variableIndex(_ id: ObjectID) -> VariableIndex {
        guard let index = objectToIndex[id] else {
            fatalError("Object \(id) not found in the simulation variable list")
        }
        return index
    }

    /// Compile a simulation node.
    ///
    /// The function compiles a node that represents a variable or a kind of
    /// computation.
    ///
    /// The following types of nodes are considered:
    /// - a node with a ``FormulaComponent``, compiled as a formula.
    /// - a node with a ``GraphicalFunctionComponent``, compiled as a graphical
    ///   function.
    ///
    /// - Returns: a computational representation of the simulation node.
    ///
    /// - Throws: ``NodeIssueList`` with list of issues for the node.
    /// - SeeAlso: ``compile(_:formula:)``, ``compile(_:graphicalFunction:)``.
    ///
    public func compile(_ node: Node) throws -> ComputationalRepresentation {
        let rep: ComputationalRepresentation
        if let component: FormulaComponent = node.snapshot[FormulaComponent.self] {
            rep = try compile(node, formula: component)
        }
        else if let component: GraphicalFunctionComponent = node.snapshot[GraphicalFunctionComponent.self] {
            rep = try compile(node, graphicalFunction: component)
        }
        else {
            // Hint: If this error happens, then either check the following:
            // - the condition in the stock-flows view method returning
            //   simulation nodes
            // - whether the object memory constraints work properly
            // - whether the object memory metamodel is stock-flows metamodel
            //   and that it has necessary components
            //
            fatalError("Node \(node.snapshot) is not known as a simulation node, can not be compiled.")
        }
        return rep
    }

    // FIXME: Update documentation
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
    /// - Throws: ``NodeIssueList`` with list of issues for the node.
    ///
    public func compile(_ node: Node,
                        formula: FormulaComponent) throws -> ComputationalRepresentation{
        // FIXME: [IMPORTANT] Parse expressions in a compiler sub-system, have it parsed here already
        let unboundExpression: UnboundExpression
        do {
            unboundExpression =  try formula.parsedExpression()!
        }
        catch let error as ExpressionSyntaxError {
            throw NodeIssueList([NodeIssue.expressionSyntaxError(error)])
        }
        
        // List of required parameters: variables in the expression that
        // are not built-in variables.
        //
        let required: [String] = unboundExpression.allVariables.filter {
            !builtinVariableNames.contains($0)
        }

        // TODO: [IMPORTANT] Move this outside of this method. This is not required for binding
        // Validate parameters.
        //
        let inputIssues = validateParameters(node.id, required: required)
        guard inputIssues.isEmpty else {
            throw NodeIssueList(inputIssues)
        }
        
        // Finally bind the expression.
        //
        let boundExpression = try bindExpression(unboundExpression,
                                                 variables: namedReferences,
                                                 functions: functions)
        return .formula(boundExpression)
    }

    /// - Requires: node
    /// - Throws: ``NodeIssueList`` with list of issues for the node.
    ///
    public func compile(_ node: Node,
                        graphicalFunction: GraphicalFunctionComponent) throws -> ComputationalRepresentation{
        let hood = view.incomingParameters(node.id)
        guard let parameterNode = hood.nodes.first else {
            throw NodeIssueList([.missingGraphicalFunctionParameter])
        }
        
        let funcName = "__graphical_\(node.id)"
        let numericFunc = graphicalFunction.function.createFunction(name: funcName)

        return .graphicalFunction(numericFunc, variableIndex(parameterNode.id))

    }

    /// - Throws: ``NodeIssueList`` with list of issues for the node.
    ///
    public func compile(stocks: [Node]) throws -> [CompiledStock] {
        var outflows: [ObjectID: [ObjectID]] = [:]
        var inflows: [ObjectID: [ObjectID]] = [:]

        for edge in view.drainsEdges {
            // Drains edge: stock ---> flow
            let stock = edge.origin
            let flow = edge.target
            outflows[stock,default:[]].append(flow)
        }

        for edge in view.fillsEdges {
            // Fills edge: flow ---> stock
            let stock = edge.target
            let flow = edge.origin
            inflows[stock, default: []].append(flow)
        }

        // Sort the outflows by priority
        for stock in stocks {
            let sortedOutflows = outflows[stock.id]?.map {
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
            outflows[stock.id] = sortedOutflows ?? []
        }
                
        var result: [CompiledStock] = []
        
        for node in stocks {
            let inflowIndices = inflows[node.id]?.map { variableIndex($0) } ?? []
            let outflowIndices = outflows[node.id]?.map { variableIndex($0) } ?? []
            guard let component: StockComponent = node.snapshot[StockComponent.self] else {
                fatalError("Stock type object has no stock component")
            }
            let compiled = CompiledStock(
                id: node.id,
                index: variableIndex(node.id),
                component: component,
                inflows: inflowIndices,
                outflows: outflowIndices
            )
            result.append(compiled)
        }
        return result
    }
    
    // FIXME: Update documentation
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
        let parameters = view.parameters(nodeID, required: required)
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
