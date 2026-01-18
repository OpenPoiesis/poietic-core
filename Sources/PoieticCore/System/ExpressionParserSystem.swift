//
//  ExpressionParserSystem.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 02/11/2025.
//

/// Parsed arithmetic expression (frame-independent)
public struct ParsedExpressionComponent: Component {
    public let expression: UnboundExpression
    public let variables: Set<String>
}

/// System that parses formulas into unbound expressions.
///
/// - **Input:** Objects with trait ``Trait/Formula``.
/// - **Output:** ``ParsedExpressionComponent`` component.
/// - **Forgiveness:** Objects with missing or invalid `formula` attribute will be ignored.
///
public struct ExpressionParserSystem: System {
    public init(_ world: World) { }
    public func update(_ world: World) {
        guard let frame = world.frame else { return }
        
        for object in frame.filter(trait: .Formula) {
            guard let formula: String = object["formula"] else { continue }
            parseExpression(formula, object: object, in: world)
            
        }
    }
    func parseExpression(_ formula: String, object: ObjectSnapshot, in world: World) {
        do {
            let expr: UnboundExpression
            let component: ParsedExpressionComponent
            let parser = ExpressionParser(string: formula)
            expr = try parser.parse()
            component = ParsedExpressionComponent(
                expression: expr,
                variables: Set(expr.allVariables)
            )
            world.setComponent(component, for: object.objectID)
        }
        catch {
            let issue = Issue(
                identifier: "syntax_error",
                severity: .error,
                system: self,
                error: error,
                details: [
                    "attribute": "formula",
                    "underlying_error": Variant(error.description),
                ]
            )

            world.appendIssue(issue, for: object.objectID)
        }

    }
}
