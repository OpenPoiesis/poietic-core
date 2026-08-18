# Formulas

Formulas are arithmetic expressions that can be used for computation.

## Overview

The library provides a way to parse and express arithmetic expressions as
structures that can be further transformed or directly used for computation.

```swift
let parser = ExpressionParser(string: "a + (b * 10)")
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
| `^` | Power |

Comparison operators:

| Operator | Description |
| ---- | ---- |
| `==` | Equal |
| `!=` | Not equal |
| `>` | Greater than |
| `>=` | Greater or equal than |
| `<` | Less than |
| `<=` | Less or equal than |

Arithmetic functions:

| Name | Description |
| ---- | ---- | 
| `abs(x)` | Absolute value |
| `floor(x)` | Rounding downwards to the nearest integer |
| `ceiling(x)` | Rounding upwards to the nearest integer |
| `round(x)` | Rounding to the nearest integer |
| `power(x,e)` | Power of _x_ to _e_ |
| `exp(x)` | Natural exponent of _x_ |
| `sqrt(x)` | Square root of _x_ |
| `sum(a,...)` | Sum of multiple values |
| `min(a,b,...)` | Minimum value from a list of values |
| `max(a,b,...)` | Maximum value from a list of values |

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
- ``UnaryOperator``
- ``BinaryOperator``
- ``BuiltinFunction``
- ``FunctionError``

### Evaluation

- ``Evaluator``
- ``EvaluationError``
- ``VariableNameLookup``
- ``VariableValueLookup``
- ``TypedVariable``

### Parsing

- ``ExpressionParser``
- ``TextLocation``
- ``ExpressionLexer``
- ``ExpressionToken``
- ``ExpressionSyntaxError``
- ``ExpressionError``

### Abstract Syntax Tree

- ``ExpressionAST``
