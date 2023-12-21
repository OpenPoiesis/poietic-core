//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

/// Component representing a position of a node in a canvas.
///
public struct PositionComponent: InspectableComponent,
                                 CustomStringConvertible {
    
    // TODO: Consider renaming this to DiagramComponent, CanvasComponent or GraphicsComponent

    public static var componentSchema = ComponentSchema(
        name: "Position",
        attributes: [
            Attribute(name: "position", type: .point),
            Attribute(name: "z_index", type: .int),
        ]
    )
    /// Position of object's centre.
    ///
    public var position: Point = Point()
    
    /// Order in which the objects are placed on a canvas.
    ///
    /// Higher z-index means more to the front, lower z-index means more to the
    /// back of the canvas.
    ///
    public var zIndex: Int = 0
    
    public init() {
        self.init(x: 0.0, y: 0.0)
    }
    
    public init(_ position: Point, zIndex: Int = 0) {
        self.position = position
        self.zIndex = zIndex
    }

    public init(x: Double,
                y: Double,
                zIndex: Int = 0) {
        self.position = Point(x: x, y: y)
        self.zIndex = zIndex
    }

    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "position": return ForeignValue(position)
        case "z_index": return ForeignValue(zIndex)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "position": self.position = try value.pointValue()
        case "z_index": self.zIndex = try value.intValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
    public var description: String {
        "Position(x: \(position.x), y: \(position.y)"
    }
}


extension ObjectSnapshot {
    public var position: Point? {
        get {
            guard let comp: PositionComponent = self[PositionComponent.self] else {
                return nil
            }
            return comp.position
        }
        set(point) {
            if let point {
                self[PositionComponent.self] = PositionComponent(point)
            }
            else {
                self.components.remove(PositionComponent.self)
            }
        }
    }
}
