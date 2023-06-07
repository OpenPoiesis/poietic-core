//
//  ExpressionNode.swift
//
//
//  Created by Stefan Urbanek on 17/06/2022.
//

import PoieticCore

public typealias Point = SIMD2<Double>

// FIXME: Consider consolidating all node types into this class.
/// Component of all nodes that can contain arithmetic expression.
///
/// All components with arithmetic expression are also named components.
///
public struct ExpressionComponent: DefaultValueComponent, PersistableComponent, CustomStringConvertible {
    public var persistableTypeName: String { "ExpressionComponent" }
    
    /// Spatial location of the node.
    public var position: Point = Point()
    
    /// Name of the node
    public var name: String
    // TODO: Use both: string and expression -> depending where is the source of it
    /// Arithmetic expression
    var expressionString: String
    

    /// Creates a a default expression component.
    ///
    /// The name is set to `unnamed`, expression is set to 0 and position is a
    /// zero point.
    ///
    public init() {
        self.name = "unnamed"
        self.expressionString = "0"
        self.position = Point()
    }
    
    /// Creates an expression node.
    public init(name: String,
                expression: String,
                position: Point = Point()) {
        self.name = name
        self.expressionString = expression
        self.position = position
    }
    
    public init(record: ForeignRecord) throws {
        self.name = try record.stringValue(for: "name")
        self.expressionString = try record.stringValue(for: "expression")
        let x = try record.doubleValue(for: "position.x")
        let y = try record.doubleValue(for: "position.y")
        self.position = Point(x: x, y: y)
    }

    public init(name: String, float value: Float) {
        self.init(name: name, expression: String(value))
    }
    
    
    public var description: String {
        let typename = "\(type(of: self))"
        return "\(typename)(\(name), expr: \(expressionString))"
    }
    
        
    public var attributeKeys: [AttributeKey] {
        [
            "name",
            "expression",
            "position.x",
            "position.y"
        ]
    }
    public func attribute(forKey key: AttributeKey) -> (any AttributeValue)? {
        switch key {
        case "name": return name
        case "expression": return expressionString
        case "position.x": return position.x
        case "position.y": return position.y
        default: return nil
        }
    }
   
    public mutating func setAttribute(value: any AttributeValue, forKey key: AttributeKey) {
        switch key {
        case "name": self.name = value.stringValue()!
        case "expression": self.expressionString = value.stringValue()!
        case "position.x": self.position.x = value.doubleValue()!
        case "position.y": self.position.y = value.doubleValue()!
        default: fatalError("Unknown attribute: \(key) in \(type(of:self))")
        }
    }
}

extension ExpressionComponent {
    public static func == (lhs: ExpressionComponent, rhs: ExpressionComponent) -> Bool {
        lhs.position == rhs.position
        && lhs.name == rhs.name
        && lhs.expressionString == rhs.expressionString
    }
}
