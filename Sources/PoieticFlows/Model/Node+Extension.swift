//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/07/2023.
//

import PoieticCore

extension Node {
    /// Get a parsed expression of a node that has a ``FormulaComponent``.
    ///
    /// - Returns: Unbound expression
    /// - Throws: ``SyntaxError`` when the expression can not be parsed.
    ///
    public func parsedExpression() throws -> UnboundExpression? {
        guard let component: FormulaComponent = components[FormulaComponent.self] else {
            return nil
        }
        let parser = ExpressionParser(string: component.expressionString)
        return try parser.parse()
    }

}
