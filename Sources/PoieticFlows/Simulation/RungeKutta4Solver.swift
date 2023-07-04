//
//  RK4Solver.swift
//  
//
//  Created by Stefan Urbanek on 30/07/2022.
//



/// Solver that integrates using the Runge Kutta 4 method.
///
/// - SeeAlso: [Runge Kutta methods](https://en.wikipedia.org/wiki/Runge–Kutta_methods)
///
public class RungeKutta4Solver: Solver {
    /*
        RK4:
     
        dy/dt = f(t,y)
         
        k1 = f(tn, yn)
        k2 = f(tn + h/2, yn + h*k1/2)
        k3 = f(tn + h/2, yn + h*k2/2)
        k4 = f(tn + h, yn + h*k3)

     yn+1 = yn + 1/6(k1 + 2k2 + 2k3 + k4)*h
     tn+1 = tn + h
    */
    override public func compute(at time: Double, with state: StateVector, timeDelta: Double = 1.0) -> StateVector {
        let k1 = difference(at: time,
                            with: state,
                            timeDelta: timeDelta)
        let k2 = difference(at: time + timeDelta / 2,
                            with: state + (timeDelta / 2) * k1,
                            timeDelta: timeDelta / 2)
        let k3 = difference(at: time + timeDelta / 2,
                            with: state + (timeDelta / 2) * k2,
                            timeDelta: timeDelta / 2)
        let k4 = difference(at: time,
                            with: state + timeDelta * k3,
                            timeDelta: timeDelta)
        
        let result = state + (1.0/6.0) * timeDelta * (k1 + 2 * k2 + 2*k3 + k4)

        return result
    }
}
