//
//  Simulator.swift
//  
//
//  Created by Stefan Urbanek on 25/08/2023.
//

import PoieticCore

/// Object for controlling a simulation session.
///
public class Simulator {
    /// Object memory in which the simulator operates.
    public var memory: ObjectMemory
    
    /// List of systems that the simulator will call during various stages
    /// of the simulation process.
    ///
    public var systems: [any SimulationSystem]
    
    /// Solver to be used for the simulation.
    public var solverType: Solver.Type
    public var solver: Solver?
    
    // Simulation parameters

    /// Initial time of the simulation.
    public var initialTime: Double = 0
    
    /// Time between simulation steps.
    public var timeDelta: Double = 1.0
    
    // MARK: - Simulator state
    
    /// Current simulation step
    public var currentStep: Int = 0
    public var currentTime: Double = 0
    public var state: StateVector
    public var frame: MutableFrame?
    public var compiledModel: CompiledModel?
    
    // MARK: - Initialization
    
    public init(memory: ObjectMemory, solverType: Solver.Type = EulerSolver.self) {
        self.memory = memory
        self.solverType = solverType
        self.state = StateVector()
        
        // TODO: Make this not built-in
        systems = [
            ControlBindingSystem()
        ]
    }

    // MARK: - Compilation methods
    
    public func compile(_ frame: MutableFrame) throws {
        self.frame = frame
        
        let compiler = Compiler(frame: frame)
        
        let context = CompilationContext(frame: frame)
        for system in systems {
            system.prepareForCompilation(context)
        }

        let compiledModel = try compiler.compile()

        for system in systems {
            system.didCompile(context, model: compiledModel)
        }
        
        self.compiledModel = compiledModel
    }
    
    // MARK: - Simulation methods
    
    public func initializeSimulation() {
        guard let frame = self.frame else {
            fatalError("Trying to initialize a simulation without a frame")
        }
        guard let model = self.compiledModel else {
            fatalError("Trying to step a simulation without a compiled model")
        }
        currentStep = 0
        currentTime = initialTime
        
        solver = solverType.init(model)
        state = solver!.initialize(time: currentTime)

        let context = SimulationContext(
            time: currentTime,
            timeDelta: timeDelta,
            step: currentStep,
            state: state,
            frame: frame,
            model: model)

        print("INIT STATE: \(state)")
        for system in systems {
            system.prepareForRunning(context)
        }
    }
    
    /// Perform one step of the simulation.
    ///
    /// - Precondition: Frame and model must exist.
    ///
    public func step() {
        guard let frame = self.frame else {
            fatalError("Trying to step a simulation without a frame")
        }
        guard let model = self.compiledModel else {
            fatalError("Trying to step a simulation without a compiled model")
        }
        guard let solver = self.solver else {
            fatalError("Trying to step a simulation without a solver")
        }
        currentStep += 1
        currentTime += timeDelta
        
        state = solver.compute(at: currentTime,
                               with: state,
                               timeDelta: timeDelta)
        print("STATE: \(state)")
        
        let context = SimulationContext(
            time: currentTime,
            timeDelta: timeDelta,
            step: currentStep,
            state: state,
            frame: frame,
            model: model)

        for system in systems {
            system.didStep(context)
        }
    }
}
