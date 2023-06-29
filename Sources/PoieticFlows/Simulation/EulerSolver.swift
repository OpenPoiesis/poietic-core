//
//  EulerSolver.swift
//  
//
//  Created by Stefan Urbanek on 30/07/2022.
//

public class EulerSolver: Solver {
    public override func compute(at time: Double,
                          with current: StateVector,
                          timeDelta: Double = 1.0) throws -> StateVector {
        let delta = try difference(at: time,
                                   with: current,
                                   timeDelta: timeDelta)
        
        let result = current + (delta * timeDelta)
        return result
    }

}
