//
//  ExpressionNode.swift
//
//
//  Created by Stefan Urbanek on 17/06/2022.
//

import PoieticCore

// FIXME: Consider consolidating all node types into this class.
/// Component of all nodes that can contain arithmetic formula or a constant.
///
/// All components with arithmetic formula are also named components.
///
public struct FormulaComponent: Component,
                                   CustomStringConvertible {
    
    public static var componentDescription = ComponentDescription(
        name: "Formula",
        attributes: [
            AttributeDescription(
                name: "name",
                type: .string,
                abstract: "Node name. Can be used to refer to the node in in formulas."),
            AttributeDescription(
                name: "formula",
                type: .string,
                abstract: "Arithmetic formula or a constant value represented by the node."
            ),
        ]
    )
    
    /// Name of the node
    public var name: String
    // TODO: Use both: string and expression -> depending where is the source of it
    /// Arithmetic expression
    public var expressionString: String
    
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
                expression: String) {
        self.name = name
        self.expressionString = expression
    }
    
    // TODO: Deprecate
    public init(name: String, float value: Float) {
        self.init(name: name, expression: String(value))
    }
    
    
    public var description: String {
        return "Formula(\(name), '\(expressionString))'"
    }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "name": return ForeignValue(name)
        case "formula": return ForeignValue(expressionString)
        default: return nil
        }
    }

    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "name": self.name = try value.stringValue()
        case "formula": self.expressionString = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

extension FormulaComponent {
    public static func == (lhs: FormulaComponent, rhs: FormulaComponent) -> Bool {
        lhs.name == rhs.name
        && lhs.expressionString == rhs.expressionString
    }
}
