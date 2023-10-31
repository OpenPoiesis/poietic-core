//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//
import PoieticCore

/// Component representing a position of a node in a canvas.
///
public struct PositionComponent: InspectableComponent,
                                 CustomStringConvertible {
    
    // TODO: Consider renaming this to CanvasComponent or GraphicsComponent

    public static var componentSchema = ComponentSchema(
        name: "Position",
        attributes: [
            Attribute(name: "position", type: .point),
//            AttributeDescription(name: "x", type: .double),
//            AttributeDescription(name: "y", type: .double),
        ]
    )
    /// Flag whether the value of the node can be negative.
    public var position: Point = Point()
    
    public init() {
        self.init(x: 0.0, y: 0.0)
    }
    
    public init(_ position: Point) {
        self.position = position
    }

    public init(x: Double,
                y: Double) {
        self.position = Point(x: x, y: y)
    }

    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "position": return ForeignValue(position)
//        case "x": return ForeignValue(position.x)
//        case "y": return ForeignValue(position.y)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "position": self.position = try value.pointValue()
//        case "x": self.position.x = try value.doubleValue()
//        case "y": self.position.y = try value.doubleValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
    public var description: String {
        "Position(x: \(position.x), y: \(position.y)"
    }
}
