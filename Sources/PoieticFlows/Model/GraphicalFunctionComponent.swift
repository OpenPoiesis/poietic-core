//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/07/2023.
//

import PoieticCore

public struct GraphicalFunctionComponent: Component {
    public static var componentDescription = ComponentDescription(
        name: "GraphicalFunction",
        attributes: [
            AttributeDescription(
                name: "interpolation_method",
                type: .string,
                abstract: "Method of interpolation for values between the points."),
            AttributeDescription(
                name: "points",
                type: .point,
                abstract: "Points of the graphical function."),
        ]

    )
    
    var points: [Point]
    var method: InterpolationMethod

    public init() {
        // What the swift ... look at this function's modifiers
        self.init(points: [], method: .step)
    }
    
    public init(points: [Point], method: InterpolationMethod = .step) {
        self.points = points
        self.method = method
    }

    
    public mutating func setAttribute(value: AttributeValue, forKey key: AttributeKey) throws {
        switch key {
        case "method":
            let methodName = try value.stringValue()
            self.method = InterpolationMethod.init(rawValue: methodName) ?? .step
        case "points":
            points = try value.pointArray()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }

    }
    
    public func attribute(forKey key: String) -> AttributeValue? {
        switch key {
        case "method": return ForeignValue(method.rawValue)
        case "points": return ForeignValue(points)
        default:
            return nil
        }
    }
}
