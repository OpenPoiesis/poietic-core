//
//  ExpressionNode.swift
//
//
//  Created by Stefan Urbanek on 17/06/2022.
//

import PoieticCore

// FIXME: Consider consolidating all node types into this class.
/// Component of all nodes that can contain arithmetic expression.
///
/// All components with arithmetic expression are also named components.
///
public struct ExpressionComponent: Component,
                                   CustomStringConvertible {
    
    public static var componentDescription = ComponentDescription(
        name: "Expression",
        attributes: [
            AttributeDescription(name: "name", type: .string),
            AttributeDescription(name: "expression", type: .string),
        ]
    )
    
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
    }
    
    /// Creates an expression node.
    public init(name: String,
                expression: String,
                position: Point = Point()) {
        self.name = name
        self.expressionString = expression
    }
    
    // TODO: Deprecate
    public init(name: String, float value: Float) {
        self.init(name: name, expression: String(value))
    }
    
    
    public var description: String {
        let typename = "\(type(of: self))"
        return "\(typename)(\(name), expr: \(expressionString))"
    }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "name": return ForeignValue(name)
        case "expression": return ForeignValue(expressionString)
        default: return nil
        }
    }

    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "name": self.name = value.stringValue!
        case "expression": self.expressionString = value.stringValue!
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

extension ExpressionComponent {
    public static func == (lhs: ExpressionComponent, rhs: ExpressionComponent) -> Bool {
        lhs.name == rhs.name
        && lhs.expressionString == rhs.expressionString
    }
}
