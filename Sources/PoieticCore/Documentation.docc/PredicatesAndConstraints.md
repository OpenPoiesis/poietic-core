# Predicates and Constraints

Predicates specify conditions for filtering specific objects. Constraints
define requirements for a set of objects.

## Overview

Predicates are used for filtering specific objects from the whole memory, 
particular frame or from a graph. With predicates you can for example select 
objects of given type using ``IsTypePredicate`` or objects containing a
particular component with ``HasComponentPredicate``.

## Topics

### Predicates

- ``Predicate``
- ``CompoundPredicate``
- ``EdgePredicate``
- ``AnyPredicate``
- ``IsTypePredicate``
- ``NegationPredicate``
- ``HasComponentPredicate``
- ``AllSatisfy``
- ``ConstraintRequirement``
- ``LogicalConnective``

### Constraints

- ``Constraint``
- ``EdgeEndpointTypes``
- ``RejectAll``
- ``AcceptAll``
- ``ConstraintViolation``
- ``ConstraintViolationError``
- ``UniqueNeighbourRequirement``
- ``UniqueProperty``
