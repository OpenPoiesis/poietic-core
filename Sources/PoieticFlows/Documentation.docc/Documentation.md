# ``PoieticFlows``

Package for simulation of the _Stock and Flow_ model.

## Overview

The package is a concrete implementation of one kind of models - the
[Stock and Flow](https://en.wikipedia.org/wiki/Stock_and_flow) model.

The current implementation of the package provides very basic components
to construct the Stock and Flow models: ``FlowsMetamodel/Stock``,
``FlowsMetamodel/Flow``, ``FlowsMetamodel/Auxiliary``.

The main component of the nodes is the ``FormulaComponent`` containing 
an arithmetic formula.

More information about the model is stored in the ``FlowsMetamodel``.


## Topics

## Model and Components

- ``FlowsMetamodel``
- ``FormulaComponent``
- ``FlowComponent``
- ``StockComponent``
- ``PositionComponent``

### Compiler

- ``DomainView``
- ``Compiler``
- ``CompiledModel``
- ``DomainError``
- ``NodeIssue``

### Simulation and Solver

- ``StateVector``
- ``Solver``
- ``EulerSolver``
- ``RungeKutta4Solver``

- ``StateVector``
- ``KeyedNumericVector``

### Built-in Functions

- ``BuiltinUnaryOperators``
- ``BuiltinBinaryOperators``
- ``BuiltinFunctions``

