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
- ``FrameBase``
- ``StableFrame``
- ``MutableFrame``
- ``ObjectSnapshot``
- ``VersionState``
- ``ObjectID``
- ``SnapshotID``
- ``FrameID``
- ``IdentityGenerator``
- ``SequentialIDGenerator``

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

### Predicates and Constraints

- ``Predicate``
- ``NodePredicate``
- ``EdgePredicate``
- ``CompoundPredicate``
- ``Constraint``
- ``EdgeConstraint``
- ``NodeConstraint``
- ``EdgeEndpointTypes``
- ``EdgeObjectPredicate``
- ``AnyPredicate``
- ``RejectAll``
- ``AcceptAll``
- ``IsTypePredicate``
- ``ConstraintViolation``
- ``ConstraintViolationError``

### Foreign Interfaces

- ``ForeignValue``
- ``ForeignRecord``
- ``ForeignScalar``
- ``ForeignRecordError``

### Arithmetic Expression

- ``ArithmeticExpression``
- ``UnboundExpression``
- ``BoundExpression``
- ``BoundVariableReference``


- ``FunctionProtocol``
- ``ExpressionParser``
- ``NumericFunction``
- ``NumericUnaryOperator``
- ``NumericBinaryOperator``
- ``NumericExpressionEvaluator``
- ``FunctionArgumentError``


### Persistence and Foreign Interfaces

- ``ValueProtocol``
- ``AttributeDictionary``
- ``AttributeKey``
- ``AttributeValue``
- ``ForeignRecordError``

### Metamodel

- ``ObjectType``
- ``Component``
- ``ComponentSet``
- ``Metamodel``
- ``AttributeDescription``
- ``ComponentDescription``
