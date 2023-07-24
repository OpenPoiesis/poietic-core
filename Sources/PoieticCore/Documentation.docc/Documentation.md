# ``PoieticCore``

Core library for creating applications for systems thinking and simulation.

## Overview

The Poietic Core provides functionality to iteratively construct models that
are typically represented as a graph, such as Stock and Flow models,
causal maps or biochemical pathways.

Particular focus features of the library are:

- Allow user to experiment with a model design without worry.
- Treat user's input as holy.
- Assure sustainability, evolvability and repairability of the design data.

The core class of the model is the ``ObjectMemory`` which stores and manages
all the design objects – ``ObjectSnapshot`` – and their changes. The ``ObjectMemory`` also manages
history of changes in form of frames which might be gathered in frame
collections. One of the frame collections is the memory's history that
features undo and redo functionality.

The library focuses on category of models that are representable as graphs.
The types for graph representation are mainly ``Graph``, ``Node`` and ``Edge``.
For querying features of a graph there is ``Neighborhood`` and
``NeighborhoodSelector``.


## Topics

### Object Memory

- ``ObjectMemory``
- ``ObjectSnapshot``

- ``FrameBase``
- ``StableFrame``
- ``MutableFrame``

- ``VersionState``
- ``ObjectID``
- ``SnapshotID``
- ``FrameID``
- ``IdentityGenerator``
- ``SequentialIDGenerator``

### Metamodel

- ``ObjectType``
- ``Component``
- ``ComponentSet``
- ``Metamodel``
- ``AttributeDescription``
- ``ComponentDescription``
- ``EmptyMetamodel``
- ``NameComponent``

### Graph

- ``Graph``
- ``UnboundGraph``
- ``MutableGraph``
- ``MutableUnboundGraph``

- ``Node``
- ``Edge``
- ``EdgeDirection``

- ``Neighborhood``
- ``NeighborhoodSelector``

- ``GraphCycleError``

### Predicates

- ``Predicate``
- ``NodePredicate``
- ``EdgePredicate``
- ``CompoundPredicate``
- ``EdgeObjectPredicate``
- ``AnyPredicate``
- ``IsTypePredicate``
- ``NegationPredicate``
- ``HasComponentPredicate``

### Constraints

- ``Constraint``
- ``EdgeConstraint``
- ``NodeConstraint``
- ``EdgeEndpointTypes``
- ``RejectAll``
- ``AcceptAll``
- ``ConstraintViolation``
- ``ConstraintViolationError``
- ``UniqueNeighbourRequirement``
- ``UniqueProperty``

### Foreign Interfaces

- ``ForeignValue``
- ``ForeignRecord``
- ``ForeignAtom``
- ``ForeignRecordError``

### Arithmetic Expression

- ``ArithmeticExpression``
- ``UnboundExpression``
- ``BoundExpression``
- ``BoundVariableReference``
- ``BuiltinVariable``

- ``FunctionProtocol``
- ``NumericFunction``
- ``NumericUnaryFunction``
- ``NumericBinaryFunction``

### Arithmetic Expression Parsing and Syntax

- ``Scanner``
- ``ExpressionParser``
- ``ExpressionLexer``
- ``FunctionCallSyntax``
- ``FunctionArgumentSyntax``
- ``FunctionArgumentListSyntax``
- ``ParenthesisSyntax``
- ``UnaryOperatorSyntax``
- ``BinaryOperatorSyntax``
- ``VariableSyntax``
- ``LiteralSyntax``
- ``TextLocation``
- ``Token``

### Persistence and Foreign Interfaces

- ``AttributeDictionary``
- ``AttributeKey``
- ``AttributeValue``
- ``ForeignRecordError``

