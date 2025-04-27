//
//  Point.swift
//
//
//  Created by Stefan Urbanek on 04/03/2024.
//

/// Type representing two-dimensional points.
///
public typealias Point = SIMD2<Double>

extension Point {
    public var length: Scalar {
        return (x*x + y*y).squareRoot()
    }
}
