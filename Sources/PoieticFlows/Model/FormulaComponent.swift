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
                name: "formula",
                type: .string,
                abstract: "Arithmetic formula or a constant value represented by the node."
            ),
        ]
    )
    
    /// Textual representation of the arithmetic expression.
    ///
    /// Operators: addition `+`, subtraction `-`, multiplication `*`,
    /// division `/`, remainder `%`.
    ///
    /// Functions: `abs`, `floor`, `ceiling`, `round`, `sum`, `min`, `max`.
    ///
    /// - SeeAlso: ``BuiltinFunctions``
    ///
    public var expressionString: String {
        didSet {
            let parser = ExpressionParser(string: expressionString)
            do {
                self.unboundExpression = try parser.parse()
                self.syntaxError = nil
            }
            catch let error as ExpressionSyntaxError {
                self.unboundExpression = nil
                self.syntaxError = error
            }
            catch {
                fatalError("Unknown error occurred during expression parsing: \(error). Internal hint: parser seems to be broken.")
            }
        }
    }
    
//    public enum Source {
//        case syntax(any ExpressionSyntax)
//        case string(String)
//    }
    // TODO: Allow to set the expressionSyntax, update expressionString
     internal var unboundExpression: UnboundExpression?
     internal var syntaxError: ExpressionSyntaxError?
    
    /// Creates a a default formula component.
    ///
    /// Default formula is "0".
    ///
    public init() {
        self.expressionString = "0"
    }
    
    /// Creates an expression node.
    ///
    public init(expression: String) {
        self.expressionString = expression
    }
    
    // TODO: Deprecate
    public init(float value: Float) {
        self.init(expression: String(value))
    }
    
    
    public var description: String {
        return "Formula(\(expressionString))"
    }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "formula": return ForeignValue(expressionString)
        default: return nil
        }
    }

    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "formula": self.expressionString = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

extension FormulaComponent {
    public static func == (lhs: FormulaComponent, rhs: FormulaComponent) -> Bool {
        // TODO: We should compare compiled expressions here.
        lhs.expressionString == rhs.expressionString
    }
}
