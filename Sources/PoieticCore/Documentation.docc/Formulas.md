# Formulas

Formulas are arithmetic expressions that can be used for computation.

## Overview

The library provides a way to parse and express arithmetic expressions as
structures that can be further transformed or directly used for computation.

```swift
let parser = ExpressionParser(string: "a + (b * 10))")
let expression: UnboundExpression = try parser.parse()
```

Binary arithmetic operators:

| Operator | Description |
| ---- | ---- |
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `%` | Remainder after division |

Comparison operators:

| Operator | Description |
| ---- | ---- |
| `==` | Equal |
| `!=` | Not equal |
| `>` | Greater than |
| `>=` | Greater or equal than |
| `<` | Less than |
| `<=` | Less or equal than |

Built-in logical functions:

| Name | Description |
| ---- | ---- |
| `if(cond,tval,fval)` | Returns _tval_ if the condition _cond_ is true, otherwise _fval_ |
| `not(a)` | Returns negation of boolean value _a_ |
| `or(a,b,...)` | Returns logical _OR_ of all the arguments – true if at least one is true |
| `and(a,b,...)` | Returns logical _AND_ of all the arguments – true if all arguments are true |


## Topics

### Arithmetic Expression

- ``ArithmeticExpression``
- ``UnboundExpression``

### Functions

- ``Function``
- ``Signature``
- ``FunctionArgument``
- ``BuiltinComparisonOperators``
- ``BuiltinFunctions``

### Parsing

- ``ExpressionParser``
- ``TextLocation``
- ``ExpressionLexer``
- ``ExpressionToken``
- ``TokenTypeProtocol``
- ``ExpressionSyntaxError``

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
