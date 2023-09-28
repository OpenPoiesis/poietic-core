# Formulas

Formulas - arithmetic expressions.

## Topics

### Arithmetic Expression

- ``ArithmeticExpression``
- ``UnboundExpression``
- ``BuiltinVariable``
- ``bindExpression(_:variables:functions:)``
- ``ExpressionError``
- ``ExpressionSyntaxError``

### Functions

- ``FunctionProtocol``
- ``NumericFunction``
- ``NumericUnaryFunction``
- ``NumericBinaryFunction``
- ``FunctionError``
- ``ArgumentType``
- ``Signature``

### Parsing

- ``Lexer``
- ``Scanner``
- ``ExpressionParser``
- ``ExpressionLexer``
- ``TextLocation``
- ``Token``
- ``ExpressionTokenType``
- ``TokenTypeProtocol``

### Abstract Syntax Tree

- ``ExpressionSyntax``
- ``ParenthesisSyntax``
- ``UnaryOperatorSyntax``
- ``BinaryOperatorSyntax``
- ``VariableSyntax``
- ``LiteralSyntax``
- ``FunctionCallSyntax``
- ``FunctionArgumentSyntax``
- ``FunctionArgumentListSyntax``
