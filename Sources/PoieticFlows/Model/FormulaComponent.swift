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
/// The FormulaComponent provides a textual representation of an arithmetic
/// formula of a stock, a flow, an auxiliary node.
///
/// The formula will be converted into an internal (bound) representation
/// during the compilation process. Any syntax or other errors will
/// prevent computation from happening.
///
/// Variables used in the formula refer to other nodes by their name. Nodes
/// referring to other nodes as parameters must have an edge from the
/// parameter nodes to the nodes using the parameter.
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
    
    /// Name of the node.
    ///
    /// Other nodes can refer to each other in the formula using names.
    ///
    /// Name must be unique. Otherwise the design model will not be compiled.
    ///
    /// - Note: Users must be allowed to have duplicate names in their models
    ///         during the design phase. An error might be indicated to the
    ///         user before the compilation, if a duplicate name is detected,
    ///         however the design process must not be prevented.
    ///
    public var name: String
    // TODO: Use both: string and expression -> depending where is the source of it

    /// Textual representation of the arithmetic expression.
    ///
    /// Operators: addition `+`, subtraction `-`, multiplication `*`,
    /// division `/`, remainder `%`.
    ///
    /// Functions: `abs`, `floor`, `ceiling`, `round`, `sum`, `min`, `max`.
    ///
    /// - SeeAlso: ``BuiltinFunctions``
    ///
    public var expressionString: String
    
    /// Creates a a default expression component.
    ///
    /// The name is set to `unnamed`, expression is set to 0.
    ///
    public init() {
        self.name = "unnamed"
        self.expressionString = "0"
    }
    
    /// Creates an expression node.
    ///
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
