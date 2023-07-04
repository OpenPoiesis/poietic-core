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
        let delta = difference(at: time,
                               with: current,
                               timeDelta: timeDelta)
        
        let result = current + (delta * timeDelta)
        return result
    }

}
