//
//  EulerSolver.swift
//  
//
//  Created by Stefan Urbanek on 30/07/2022.
//

/// Solver that integrates using the Euler method.
///
/// - SeeAlso: [Euler method](https://en.wikipedia.org/wiki/Euler_method)
///
public class EulerSolver: Solver {
    public override func compute(at time: Double,
                          with current: StateVector,
                          timeDelta: Double = 1.0) -> StateVector {
        let stage = prepareStage(at: time, with: current, timeDelta: timeDelta)
        let delta = difference(at: time,
                               with: stage,
                               timeDelta: timeDelta)
        
        let result = stage + (delta * timeDelta)
        return result
    }

}
