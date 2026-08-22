//
//  ExpressionParserSystem.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 02/11/2025.
//

/// Parsed arithmetic expression (plane-independent)
public struct ParsedExpressionComponent: Component {
    public let expression: UnboundExpression
    public let variables: Set<String>
    
    public init(expression: UnboundExpression) {
        self.expression = expression
        self.variables = Set(expression.allVariables)
    }
}

/// System that parses formulas into unbound expressions.
///
/// - **Input:** Objects with trait ``Trait/Formula``.
/// - **Output:** ``ParsedExpressionComponent`` component.
/// - **Forgiveness:** Objects with missing or invalid `formula` attribute will be ignored.
///
public struct ExpressionParserSystem: System {
    public static func update(_ world: World) throws (InternalSystemError) {
        guard let plane = world.plane else { return }
        
        for object in plane.filter(trait: .Formula) {
            guard let formula: String = object["formula"],
                  let entity = world.entity(object.objectID)
            else { continue }
            parseExpression(formula, object: object, entity: entity)
            
        }
    }

    static func parseExpression(_ formula: String, object: ObjectSnapshot, entity: RuntimeEntity) {
        let expr: UnboundExpression
        let component: ParsedExpressionComponent
        let parser = ExpressionParser(string: formula)
        do {
            expr = try parser.parse()
        }
        catch {
            var details: [String:Variant] = error.details
            // TODO: Add parser position and token range
            details["attribute"] = "formula"
            let issue = Issue(
                identifier: error.issueIdentifier,
                severity: .error,
                source: "ExpressionParserSystem",
                message: error.message,
                hints: error.hints,
                details: details
            )

            entity.appendIssue(issue)
            return
        }
        component = ParsedExpressionComponent(expression: expr)
        entity.setComponent(component)
    }
}
