//
//  SimulationTimeSettings.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 05/09/2026.
//

// TODO: [REFACTORING] NEW - now unused, but will replace SimulationSettings in Flows
/// Settings of the simulation time.
///
/// - SeeAlso: ``ScenarioParameters``.
///
public struct SimulationTimeSettings: Component {
    public static let StartTimeAttributeName = "start_time"
    public static let TimeStepAttributeName = "time_step"
    public static let FinalTimeAttributeName = "final_time"
    
    /// Time of the initialisation step (step 0) of the simulation.
    public var startTime: Double
    
    // NOTE: timeStep vs. timeDelta: Familiarity with the former in simulation domain.
    /// Advancement of time for each simulation step.
    public var timeStep: Double

    // NOTE: finalTime vs. stopTime: Reserving "stop time" for event based or resumable interruption
    /// Final time of the simulation.
    ///
    /// Simulation is run while the simulation is less than ``finalTime``.
    public var finalTime: Double

    /// Number of steps to run.
    ///
    public var steps: Int {
        if timeStep > 0 {
            let value = ((finalTime - startTime) / timeStep )
            return Int((value + 1e-9).rounded(.down))
        }
        else {
            return 0
        }
    }
        
    /// Create new simulation settings.
    ///
    /// - Parameters:
    ///     - startTime: Time of the initialisation step of the simulation.
    ///     - timeStep: Advancement of time for each simulation step.
    ///     - finalTime: Final simulation time. Simulation runs until _time ≤ finalTime_.
    ///
    public init(startTime: Double = 0.0, timeStep: Double = 1.0, finalTime: Double = 10.0)
    {
        self.startTime = startTime
        self.timeStep = timeStep
        self.finalTime = max(self.startTime, finalTime)
    }

    public init(startTime: Double = 0.0, timeStep: Double = 1.0, steps: Int)
    {
        self.startTime = startTime
        self.timeStep = timeStep
        self.finalTime = startTime + Double(steps) * timeStep
    }

    /// Create time settings from object attributes.
    ///
    /// Expected keys: `start_time`, `final_time` and `time_step`.
    ///
    public init(fromObject object: ObjectSnapshot) {
        // TODO: Remove backward-compatible keys once happy
        // We are using backward-compatible keys initial_time and end_time.
        // No need to document backward-compatible keys, as no wild models (should) have them.
        let startTime: Double = object["start_time"] ?? object["initial_time"] ?? 0.0
        let timeStep: Double = object["time_step"] ?? object["time_delta"] ?? 1.0

        if let finalTime: Double = object["final_time"] ?? object["end_time"] {
            self.init(startTime: startTime, timeStep: timeStep, finalTime: finalTime)
        }
        else if let steps: Int = object["steps"], steps >= 0 {
            self.init(startTime: startTime, timeStep: timeStep, steps: steps)
        }
        else {
            self.init(startTime: startTime, timeStep: timeStep, steps: 0)
        }
    }
}

