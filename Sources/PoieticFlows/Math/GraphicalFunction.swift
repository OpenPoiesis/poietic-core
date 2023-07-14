//
//  GraphicalFunction.swift
//
//
//  Created by Stefan Urbanek on 07/07/2023.
//

import PoieticCore

public enum InterpolationMethod: String, CaseIterable {
    case step = "step"
}

//enum GraphicalFunctionPresetDirection {
//    case growth
//    case decline
//}
//
//enum GraphicalFunctionPreset {
//    case data
//    case exponential
//    case logarithmic
//    case linear
//    case sShape
//}

// FIXME: This is a late-night sketch implementation, GFComponent + GF should be merged
public class GraphicalFunction {
    let method: InterpolationMethod = .step
    var points: [Point]
    
    /// Points sorted by time – by x value.
    ///
    lazy var sortedByX: [Point] = {
        points.sorted { (lhs, rhs) in
            lhs.x > rhs.x
        }
    }()

    // Presets:
    // - exponential growth
    // - exponential decay
    // - logarithmic growth
    // - logarithmic decay
    // - linear growth
    // - linear decay
    // - S-shaped growth
    // - S-shaped decline
    
    convenience init(values: [Double],
         start startTime: Double = 0.0,
         timeDelta: Double = 1.0) {

        var result: [Point] = []
        var time = startTime
        for value in values {
            result.append(Point(x: time, y:value))
            time += timeDelta
        }
        self.init(points: result)
    }
    
    public init(points: [Point]) {
        self.points = points
    }
    
    /// Function that finds the nearest time point and returns its y-value.
    ///
    /// If the graphical function has no points specified then it returns
    /// zero.
    ///
    public func stepFunction(x: Double) -> Double {
        let point = nearestXPoint(x)
        return point.y
    }
    
    /// Creates an unary function used in computation that wraps
    /// this graphical function.
    ///
    /// Current implementation just wraps the ``stepFunction(time:)``.
    ///
    public func createFunction(name: String) -> NumericUnaryFunction {
        
        let function = NumericUnaryFunction(
            name: name,
            argumentName: "x",
            implementation: self.stepFunction)
        
        return function
    }
    /// Get a point that is nearest in the x-axis to the value specified.
    ///
    /// If the graphical function has no points specified then it returns
    /// point at zero.
    ///
    func nearestXPoint(_ x: Double) -> Point {
        guard !points.isEmpty else {
            return Point()
        }
        var nearest = points.first!
        var nearestDistance = abs(x - nearest.x)
        
        for point in points.dropFirst() {
            let distance = abs(x - point.x)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = point
            }
        }
        
        return nearest
    }
}
