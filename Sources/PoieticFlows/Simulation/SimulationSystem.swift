//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 05/09/2023.
//


import PoieticCore

public struct CompilationContext {
    let frame: MutableFrame
}

public struct SimulationContext {
    // let isRunning: Bool
    let time: Double
    let timeDelta: Double
    let step: Int
    let state: StateVector
    let frame: MutableFrame // TODO: Should be stable frame
    let model: CompiledModel
}

/// Protocol for systems that support the simulation.
///
/// The simulation system operates in two phases: compilation and simulation.
/// The compilation phase transforms the design into an internal representation
/// that can be interpreted. The simulation phase is an iterative phase
/// of simulation steps.
///
/// The typical flow is:
///
/// 1. Prepare for compilation with ``SimulationContext``
/// 2. Perform tasks after compilation
///
/// -
public protocol SimulationSystem {
    /// Update the design with custom objects, before compilation
    ///
    /// This method is called when:
    ///
    /// - Model has been edited
    /// - Simulation was reset, when running interactive simulation
    ///
    func prepareForCompilation(_ context: CompilationContext)
    /// Compiled model has been created, use it
    func didCompile(_ context: CompilationContext, model: CompiledModel)

    /// Called before the first step of the simulation is run.
    func prepareForRunning(_ context: SimulationContext)

    // TODO: Rename to update() and remove didStop(), use some flag in context, for example "isRunning"
    /// Simulation step has been finished
    func didStep(_ context: SimulationContext)
    /// The simulation has been finished
    func didStop(_ context: SimulationContext)
}

extension SimulationSystem {
    public func prepareForCompilation(_ context: CompilationContext) {
        // Do nothing
    }

    public func didCompile(_ context: CompilationContext, model: CompiledModel) {
        // Do nothing
    }

    public func prepareForRunning(_ context: SimulationContext) {
        // Do nothing
    }

    public func didStep(_ context: SimulationContext) {
        // Do nothing
    }

    public func didStop(_ context: SimulationContext) {
        // Do nothing
    }
}

// MARK: - Systems

public struct ControlBindingSystem: SimulationSystem {
    public func prepareForRunning(_ context: SimulationContext) {
        updateValues(context)
    }
    
    public func didStep(_ context: SimulationContext) {
        updateValues(context)
    }

    public func updateValues(_ context: SimulationContext) {
        print("UPDATING BINDINGS (count: \(context.model.valueBindings.count))")
        for binding in context.model.valueBindings {
            print("BINDING: \(binding)")
            let value = context.state[binding.target]!
            let control = context.frame.mutableObject(binding.control)
            control[ControlComponent.self]!.value = value
        }
    }
}

