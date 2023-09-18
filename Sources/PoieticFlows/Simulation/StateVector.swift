//
//  StateVector.swift
//  
//
//  Created by Stefan Urbanek on 30/07/2022.
//

import PoieticCore

// TODO: [REFACTOR] This should be a proper vector, not a dictionary.


/// A simple vector-like structure to hold an unordered collection of numeric
/// values that can be accessed by key. Simple arithmetic operations can be done
/// with the structure, such as addition, subtraction and multiplication
/// by a scalar value.
///
public struct SimulationState: CustomStringConvertible {
    
    public var model: CompiledModel
    /// Values of built-in variables.
    public var builtins: [ForeignValue] = []
    /// Values of design objects.
    public var values: [Double]

    /// Create a simulation state with all variables set to zero.
    ///
    /// The list of builtins and simulation variables will be initialised
    /// according to the count of the respective variables in the compiled
    /// model.
    ///
    public init(model: CompiledModel) {
        self.builtins = Array(repeating: ForeignValue(0),
                              count: model.builtinVariables.count)
        self.values = Array(repeating: 0,
                           count: model.simulationVariables.count)
        self.model = model
    }
    
    public init(_ items: [Double], builtins: [ForeignValue], model: CompiledModel) {
        precondition(items.count == model.simulationVariables.count,
                     "Count of items (\(items.count) does not match required items count \(model.simulationVariables.count)")
        self.builtins = builtins
        self.values = items
        self.model = model
    }

    /// Get or set an object value at given index.
    ///
    @inlinable
    public subscript(rep: IndexRepresentable) -> Double {
        get {
            return values[rep.index]
        }
        set(value) {
            values[rep.index] = value
        }
    }
    
    /// Get or set an object value at given index.
    ///
    @inlinable
    public subscript(index: Int) -> Double {
        get {
            return values[index]
        }
        set(value) {
            values[index] = value
        }
    }
    
    /// Create a new state with variable values multiplied by given value.
    ///
    /// The built-in values will remain the same.
    ///
    @inlinable
    public func multiplied(by value: Double) -> SimulationState {
        return SimulationState(values.map { value * $0 },
                               builtins: builtins,
                               model: model)

    }
    
    /// Create a new state by adding each value with corresponding value
    /// of another state.
    ///
    /// The built-in values will remain the same.
    ///
    /// - Precondition: The states must be of the same length.
    ///
    public func adding(_ state: SimulationState) -> SimulationState {
        precondition(model.simulationVariables.count == state.model.simulationVariables.count,
                     "Simulation states must be of the same length.")
        let result = zip(values, state.values).map {
            (lvalue, rvalue) in lvalue + rvalue
        }
        return SimulationState(result,
                               builtins: builtins,
                               model: model)

    }

    /// Create a new state by subtracting each value with corresponding value
    /// of another state.
    ///
    /// The built-in values will remain the same.
    ///
    /// - Precondition: The states must be of the same length.
    ///
    public func subtracting(_ state: SimulationState) -> SimulationState {
        precondition(model.simulationVariables.count == state.model.simulationVariables.count,
                     "Simulation states must be of the same length.")
        let result = zip(values, state.values).map {
            (lvalue, rvalue) in lvalue - rvalue
        }
        return SimulationState(result,
                               builtins: builtins,
                               model: model)

    }
    
    /// Create a new state with variable values divided by given value.
    ///
    /// The built-in values will remain the same.
    ///
    @inlinable
    public func divided(by value: Double) -> SimulationState {
        return SimulationState(values.map { value / $0 },
                               builtins: builtins,
                               model: model)

    }

    @inlinable
    public static func *(lhs: Double, rhs: SimulationState) -> SimulationState {
        return rhs.multiplied(by: lhs)
    }

    @inlinable
    public static func *(lhs: SimulationState, rhs: Double) -> SimulationState {
        return lhs.multiplied(by: rhs)
    }
    public static func /(lhs: SimulationState, rhs: Double) -> SimulationState {
        return lhs.divided(by: rhs)
    }
    public var description: String {
        let builtinsStr = builtins.enumerated().map { (index, value) in
            let builtin = model.builtinVariables[index]
            return "\(builtin.name): \(value)"
        }.joined(separator: ",")
        let stateStr = values.enumerated().map { (index, value) in
            let variable = model.simulationVariables[index]
            return "\(variable.id): \(value)"
        }.joined(separator: ", ")
        return "[builtins(\(builtinsStr)), values(\(stateStr))]"
    }
}


// TODO: Make proper additive arithmetic once we get rid of the map
extension SimulationState {
    public static func - (lhs: SimulationState, rhs: SimulationState) -> SimulationState {
        return lhs.subtracting(rhs)
    }
    
    public static func + (lhs: SimulationState, rhs: SimulationState) -> SimulationState {
        return lhs.adding(rhs)
    }
    
//    public static var zero: StateVector {
//        return KeyedNumericVector<Key>()
//    }
}

