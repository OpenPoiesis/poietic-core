# ``PoieticCore``

A core package for building virtual laboratories. 

## Overview

PoieticCore is a foundation for building virtual laboratories: interactive modelling-and-simulation
applications. It is neither a modelling tool, nor a modelling methodology; it is a foundation on
which you build tools for modellers – domain experts.

Concrete methodologies are provided by other packages. For example, Stock and Flow domain is
provided in the [PoieticFlows](https://github.com/openpoiesis/poietic-flows).

### Nature of Models

PoieticCore is for models whose nature is a network: a collection of discrete elements connected
by relationships, where the connections are themselves part of the modeller's creation. The elements
and relationships can be named and are meaningful. _The network must be the model, not an
implementation detail._

Not all domains might fit. A problem domain might have a _relational aspect_ and a
_continuous aspect_. Here are examples of some domains where the relational aspect can be modelled
using the library:

- System dynamics — stocks (boxes) and flows (pipes).
- Causal maps / causal loop diagrams — variables as nodes, causal influence as edges.
- Biochemical / metabolic pathways — molecules as nodes, reactions as edges.
- Supply / value chains — processes as nodes, material or value flow as edges.
- Ecosystem food webs — species as nodes, predation as edges.
- Project/task dependency graphs — tasks as nodes, dependencies as edges.
- Social or organisational networks — people/units as nodes, relationships as edges.

- Tip: Ask the following question, and if the answer is _yes_, then this library might be suitable:

  _Can you draw the model diagrammatically – as boxes and arrows, where not only the boxes but
  also the connections between the boxes are meaningful content?_

Not suitable for:

- Equation-only models – a model specified as a few equations with no meaningful entities
  to make a structure of.
- Continuous/spatial physics – particle systems, fluids, aerodynamics. The underlying reality is
  continuous.

### Concepts

**Design and World**: The model lives in ``Design``, which is the _source of truth_. The design is a persistent and
immutable record of the model's objects and their history of changes. A ``World`` is a working
instance of the model, where experimentation and interaction happen.

**Changes and Planes**: You never modify the design in-place. You begin a change with
``Design/createPlane(deriving:id:)``, make as many changes as you need and then accept it with
``Design/accept(_:appendHistory:)``. Each group of changes produces a new ``Plane``,
which represents a version snapshot (can be an alternative of the user's idea).

Semantic errors are allowed. You indicate the errors to the user using ``RuntimeEntity/appendIssue(_:)``.
Structural integrity (such as edges pointing to existing nodes) is enforced by the library via
``Metamodel``, and that is what the application can rely on.

**Runtime and Experimentation**: Your application creates an _instance of the design_ in a world using ``World/setPlane(_:)``, typically
setting the current plane ``Design/currentPlane`` after a transaction. You read and write
interactive updates (such as dragging visuals), simulation replay states, visual representations
and other derived information in the world as components on entities (``RuntimeEntity``). You spawn
your own entities with ``World/spawn(_:)->RuntimeID`` or you can set components on entities
representing design objects (``World/entity(_:)-(ObjectID)``) that are automatically spawned on
each plane change.

### Key features

- Source of truth ``Design`` and ``ObjectSnapshot``, with transactional changes in ``Plane``.
- Domain model constraints described in ``Metamodel``.
- Runtime environment ``World`` with entities ``RuntimeEntity``
- Systems and schedules (``System``, ``Schedule``) that application registers (``World/addSchedule(_:)``)
  to update the world with ``World/run(schedule:)`` regularly or on particular events.
- Foreign interfaces for import/export such as ``JSONDesignWriter`` and ``JSONDesignReader``
- Arithmetic expression parsing ``ExpressionParser`` and evaluation ``Evaluator``.

![Core Areas](core-modules)

### Library Principles

The following principles are driving the design of the library features:

1. **Experimentation**: Applications should allow users to experiment with a model design without
    worry. Allow users to explore different versions of their ideas.
    Intermediate, even broken states of a model from a semantic perspective should be allowed.
2. **Respect**:  User's input must be respected and preserved as-is, even if it is semantically
   incorrect.
3. **Ownership**: User owns the model data through open, documented file format. Design storage
   is repairable with third party tools unrelated to this library. For example using `jq`.
4. **Extensibility and Evolution**: Library functionality can be extended.


### Related Packages

- [PoieticFlows](https://github.com/openpoiesis/poietic-flows) – Stock and Flow simulation domain model.
- [PoieticTool](https://github.com/openpoiesis/poietic-tool) – Command-line interface for editing models and running simulation.
- [PoieticPlayground](https://github.com/openpoiesis/poietic-playground) – Modelling application with a graphical user interface.


## Topics

### Modelling

- <doc:UnderstandingDesign>
- ``Design``
- ``DesignPlane``
- ``ObjectSnapshot``
- <doc:MetamodelAndTypes>

### Simulation

- <doc:RuntimeWorld>
- ``World``
- ``System``
- ``Component``

### Persistence, Import and Export

- <doc:ForeignInterfaces>
- <doc:Persistence>

### Others

- <doc:Graphs>
- <doc:Formulas>


