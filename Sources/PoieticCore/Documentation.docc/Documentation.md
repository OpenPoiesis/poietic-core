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

The core class of the model is the ``Design`` which contains and manages
all the design objects – ``ObjectSnapshot`` – and their changes. The ``Design``
also manages history of changes in form of frames which might be gathered in
frame collections. One of the frame collections is the design history that
features undo and redo functionality.

The library focuses on category of models that are representable as graphs.
The types for graph representation are mainly ``Graph``, ``Node`` and ``Edge``.
For querying features of a graph there is ``Neighborhood`` and
``NeighborhoodSelector``.


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


