//
//  ExpressionParserSystem.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 02/11/2025.
//

/// Parsed arithmetic expression (frame-independent)
public struct ParsedExpressionComponent: Component {
    // Note: We do not need to store error here, we store it in the list of all issues. It is not
    // relevant to be in the component.
    public enum Content {
        case expression(UnboundExpression)
        case error
    }
    public let content: Content
    public let variables: Set<String>

    public var isError: Bool {
        switch content {
        case .expression(_): false
        case .error: true
        }
    }
    public var expression: UnboundExpression? {
        switch content {
        case .expression(let expr): expr
        case .error: nil
        }
    }
}

/// System that parses formulas into unbound expressions.
///
/// - **Input:** Objects with trait ``Trait/Formula``.
/// - **Output:** ``ParsedExpression`` component.
/// - **Forgiveness:** Objects with missing or invalid `formula` attribute will be ignored.
///
public struct ExpressionParserSystem: System {
    public init() {}
    public func update(_ frame: RuntimeFrame) {
        for object in frame.filter(trait: .Formula) {
            guard let formula: String = object["formula"] else { continue }
            
            let expr: UnboundExpression
            let component: ParsedExpressionComponent
            
            do {
                let parser = ExpressionParser(string: formula)
                expr = try parser.parse()
                component = ParsedExpressionComponent(
                    content: .expression(expr),
                    variables: Set(expr.allVariables)
                )
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

                frame.appendIssue(issue, for: object.objectID)
                component = ParsedExpressionComponent(
                    content: .error,
                    variables: Set()
                )
            }

            frame.setComponent(component, for: object.objectID)
        }
    }
}
