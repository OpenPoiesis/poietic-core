# ``PoieticCore``

Core library for creating applications for systems thinking and simulation.

## Overview

The Poietic Core is a library that provides functionality to iteratively
construct models of systems representable as graphs. One example of such models
is a Stock and Flow model, a causal map or a biochemical pathways map.

The core functionality is:

- Design, design objects and their history
- Metamodel - domain description
- Model constraints
- Design data representation
- Simple querying
- Reading, writing, foreign interfaces and persistence
- Arithmetic expressions and functions

![Core Areas](core-modules)

The philosophy for applications on top of the library is:

- Treat user's input as holy.
- Allow user to experiment with a model design without worry.
- Assure sustainability, evolvability and repairability of the design data.

The core class of the model is the ``Design`` which contains and manages
all the design objects – ``ObjectSnapshot`` – and their changes in form of
design frames ``Frame``.

Designs are typically a part of a problem domain, or follow a methodology. The
concepts and rules of the problem domain or a methodology or both are described
in a ``Metamodel`` associated with the design. More in [Metamodel and Types](doc:MetamodelAndTypes).

See also [PoieticFlows](https://openpoiesis.github.io/PoieticFlows/documentation/poieticflows/)
package for a concrete domain use-case of the core package.


## Topics

### Essentials

- <doc:UnderstandingDesign>
- ``Design``
- ``Frame``
- ``ObjectSnapshot``

### Problem Domain

- <doc:MetamodelAndTypes>
- <doc:Predicates>

### Persistence, Import and Export

- <doc:ForeignInterfaces>
- <doc:Persistence>

### Others

- <doc:Graphs>
- <doc:Formulas>
- <doc:Runtime>


