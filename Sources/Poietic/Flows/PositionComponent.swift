//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

/// Component representing a position of a node in a canvas.
///
public struct PositionComponent: Component, PersistableComponent, CustomStringConvertible {
    // TODO: Consider renaming this to CanvasComponent or GraphicsComponent
    
    public var persistableTypeName: String { "Position" }
    
    /// Flag whether the value of the node can be negative.
    var position: Point = Point()
    
    public init(x: Double = 0,
                y: Double = 0) {
        self.position = Point(x: x, y: y)
    }
    
    public init(record: ForeignRecord) throws {
        let x = try record.doubleValue(for: "x")
        let y = try record.doubleValue(for: "y")
        self.position = Point(x: x, y: y)
    }
    
    public var attributeKeys: [AttributeKey] {
        [
            "x",
            "y"
        ]
    }
    
    public func attribute(forKey key: AttributeKey) -> (any AttributeValue)? {
        switch key {
        case "x": return position.x
        case "y": return position.y
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: any AttributeValue, forKey key: AttributeKey) {
        switch key {
        case "x": self.position.x = value.doubleValue()!
        case "y": self.position.y = value.doubleValue()!
        default: fatalError("Unknown attribute: \(key) in \(type(of:self))")
        }
    }
    public var description: String {
        "Position(x: \(position.x), y: \(position.y)"
    }
}
