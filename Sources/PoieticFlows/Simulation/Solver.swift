//
//  Solver.swift
//  
//
//  Created by Stefan Urbanek on 27/07/2022.
//
import PoieticCore

/*
 
 INIT:
    FOR EACH stock
        compute value # requires aux
 
 ITERATE:
 
    STORE initial state # make it current/last state
 
    FOR EACH STAGE:
        FOR EACH aux
            compute value
        FOR EACH flow
            compute flow rate
    ESTIMATE flows
 
 */

/// An abstract class for equations solvers.
///
/// Purpose of a solver is to initialize values of the nodes and then
/// to compute each step of the simulation.
///
/// - Note: Solver requires a compiled model. The compiled model is expected to
/// be correct, otherwise many methods of the solver will fail.
///
public class Solver {
    /// Compiled model that the solver is solving for.
    ///
    public let compiledModel: CompiledModel

    /// Arithmetic expression evaluator.
    ///
    let evaluator: NumericExpressionEvaluator

    public static private(set) var registeredSolvers: [String:Solver.Type] = [
        "euler": EulerSolver.self,
        "rk4": RungeKutta4Solver.self,
    ]
    
    public static func registerSolver(name: String, solver: Solver.Type) {
        registeredSolvers[name] = solver
    }
    
    /// Create a solver.
    ///
    /// This method is called by solver subclasses to initialize it.
    ///
    public required init(_ compiledModel: CompiledModel) {
        self.compiledModel = compiledModel
        self.evaluator = NumericExpressionEvaluator()

        var functions: [String:FunctionProtocol] = [:]
        
        for function in AllBuiltinFunctions {
            functions[function.name] = function
        }
        evaluator.functions = functions
    }

    /// Evaluate an expression within the context of a simulation state.
    ///
    /// - Parameters:
    ///     - expression: An arithmetic expression to be evaluated
    ///     - state: simulation state within which the expression is evaluated
    ///     - time: simulation time at which the evaluation takes place
    ///     - timeDelta: time difference between steps of the simulation
    ///
    /// - Returns: an evaluated value of the expression.
    ///
    /// - Precondition: The compiled model must be valid and must contain
    ///   correctly sorted nodes by their computational dependency. All variables
    ///   in the expression must be resolvable. Otherwise the function will fail.
    ///
    public func evaluate(_ expression: BoundExpression,
                         with state: StateVector,
                         at time: Double,
                         timeDelta: Double = 1.0) -> Double {
        // Clean-up variables (just in case)
        evaluator.variables.removeAll()
        for (nodeID, value) in state.items {
            evaluator.variables[.object(nodeID)] = value
        }

        // TODO: Built-in variables
        //        evaluator.variables[.builtin(FlowsMetamodel.TimeVariable)] = .double(time)
        let value: (any ValueProtocol)?
        do {
            value = try evaluator.evaluate(expression)
        }
        catch {
            // Evaluation should not fail
            fatalError("Evaluation failed: \(error)")
        }
        return value!.doubleValue()!
    }

    /// Initialize the state.
    ///
    /// - Parameters:
    ///     - `time`: Initial time. This parameter is usually not used, but
    ///     some computations in the model might use it. Default value is 0.0
    ///
    /// This function computes the initial state of the computation by
    /// evaluating all the nodes in the order of their dependency by parameter.
    ///
    /// - Returns: `StateVector` with initialized values.
    ///
    /// - Precondition: The compiled model must be valid. If the model
    ///   is not valid and contains elements that can not be computed
    ///   correctly, such as invalid variable references, this function
    ///   will fail.
    ///
    public func initialize(time: Double = 0.0) -> StateVector {
        // TODO: We need access to constants and system variables here
        var vector = StateVector()
        
        for node in compiledModel.sortedExpressionNodes {
            let expression = compiledModel.expressions[node.id]!
            vector[node.id] = evaluate(expression, with: vector, at: time)
        }

        return vector
    }

    /// Compute a difference of a stock.
    ///
    /// This function computes amount which is expected to be drained from/
    /// filled in a stock.
    ///
    /// - Parameters:
    ///     - stock: Stock for which the difference is being computed
    ///     - time: Simulation time at which we are computing
    ///     - state: Simulation state vector
    ///
    /// The flows in the state vector will be updated based on constraints.
    /// For example, if the model constains non-negative stocks and a flow
    /// trains a stock with multiple outflows, then other outflows must be
    /// adjusted or set to zero.
    ///
    /// - Precondition: The simulation state vector must have all variables
    ///   that are required to compute the stock difference.
    ///
    public func computeStock(stock stockID: ObjectID,
                        at time: Double,
                        with state: inout StateVector) -> Double {
        guard let stock = compiledModel.stockComponents[stockID] else {
            fatalError("Node \(stockID) has no Stock component")
        }

        var totalInflow: Double = 0.0
        var totalOutflow: Double = 0.0
        
        // Compute inflow (regardless whether we allow negative)
        //
        for inflow in compiledModel.inflows[stockID]! {
            totalInflow += state[inflow]!
        }
        
        if stock.allowsNegative {
            for outflow in compiledModel.outflows[stockID]! {
                totalOutflow += state[outflow]!
            }
        }
        else {
            // Compute with a constraint: stock can not be negative
            //
            // We have:
            // - current stock values
            // - expected flow values
            // We need:
            // - get actual flow values based on stock non-negative constraint
            
            // TODO: Add other ways of draining non-negative stocks, not only priority based
            
            // We are looking at a stock, and we know expected inflow and
            // expected outflow. Outflow must be less or equal to the
            // expected inflow plus current state of the stock.
            //
            // Maximum outflow that we can drain from the stock. It is the
            // current value of the stock with aggregate of all inflows.
            //
            var availableOutflow: Double = state[stockID]! + totalInflow
            let initialAvailableOutflow: Double = availableOutflow

            for outflow in compiledModel.outflows[stockID]! {
                // Assumed outflow value can not be greater than what we
                // have in the stock. We either take it all or whatever is
                // expected to be drained.
                //
                let actualOutflow = min(availableOutflow, state[outflow]!)
                
                totalOutflow += actualOutflow
                // We drain the stock
                availableOutflow -= actualOutflow
                
                // Adjust the flow value to the value actually drained,
                // so we do not fill another stock with something that we
                // did not drain.
                //
                // FIXME: We are changing the current state, we should be changing some "estimated state"
                state[outflow] = actualOutflow

                // Sanity check. This should always pass, unless we did
                // something wrong above.
                assert(state[outflow]! >= 0.0,
                       "Resulting state must be non-negative")
            }
            // Another sanity check. This should always pass, unless we did
            // something wrong above.
            assert(totalOutflow <= initialAvailableOutflow,
                   "Resulting total outflow must not exceed initial available outflow")

        }
        let delta = totalInflow - totalOutflow
        return delta
    }
    
    
    /// Comptes differences of stocks.
    ///
    /// - Returns: A state vector that contains difference values for each
    /// stock.
    ///
    func difference(at time: Double,
                    with current: StateVector,
                    timeDelta: Double = 1.0) throws -> StateVector {
        var estimate = StateVector()
        
        // 1. Evaluate auxiliaries
        //
        for aux in compiledModel.auxiliaries {
            estimate[aux] = evaluate(compiledModel.expressions[aux]!,
                                     with: current,
                                     at: time)
        }

        // 2. Estimate flows
        //
        for flow in compiledModel.flows {
            estimate[flow] = evaluate(compiledModel.expressions[flow]!,
                                      with: current,
                                      at: time)
        }

        // 3. Copy stock values that we are going to adjust for estimate
        //
        for stock in compiledModel.stocks {
            estimate[stock] = current[stock]
        }
        
        // 4. Compute stock levels
        //
        // TODO: Multiply by time delta
        var deltaVector = StateVector()

        // FIXME: IMPORTANT: This is failing when not sorted, why? (testNonNegativeTwo)
//        for compiledStock in compiledModel.stocks.sorted( by: { $0.node.id < $1.node.id}) {
        for stock in compiledModel.stocks {
            let delta = computeStock(stock: stock, at: time, with: &estimate)
            estimate[stock] = estimate[stock]! + delta
            deltaVector[stock] = delta
        }

        return deltaVector
    }
    
    public func compute(at time: Double,
                 with state: StateVector,
                 timeDelta: Double = 1.0) throws -> StateVector {
        fatalError("Subclasses of Solver are expected to override \(#function)")
    }




    
}


