# Systems

This document describes _Systems_ – objects that perform a specific function
in the object memory, frame or a graph. They are loosely based on the 
System from the [Entity-Component-System](https://en.wikipedia.org/wiki/Entity_component_system),
pattern and the delegate pattern.

The reason for this pattern in this project is mainly composability and
separation of concerns.

We consider several kinds of systems with different purpose:

- Simulation System – a system that is used during the simulation process.
- Deriving System – a system that derives additional information from existing
  frame.
- Rewriting System – a system that rewrites existing graph.

### Simulation System

A simulation system is a system that is asked to perform its functionality at
different stages of the simulation:

- after the compilation is finished – prepare structures required for simulation
- before the simulation is run – initialise structures for the new run
- after each step of the simulation – collect and update the information from
  the simulation state
- after a set of steps of the simulation is finished – finalise a simulation run
  by creating outputs, aggregating the data or notifying some other systems.

Any changes by the simulation system are assumed not to change conceptual
integrity (defined in the metamodel) of the object memory, therefore constraints
validation is not necessary after using a simulation system.

Example systems:

- updating values between controls and their bound nodes
- updating charts
- observing simulation events

Allowed operations:

- add/modify/remove transient components from objects
- modify components that are marked as modify-able by the simulation system

Not allowed operations:

- add/remove objects from a frame
- add/remove persistent components in an object

### Transformation System

Transformation system is a system that derives an information from a frame before the
compilation, usually after editing changes. 

Changes by the system are subject to constraints validation.

Example systems:

- compiling arithmetic expressions
- creating implicit flows (currently implemented as a part of the compiler)

Allowed operations:

- add/modify/remove objects of types that are associated with the system
- add/modify/remove persistent components that are associated with the system
- add/modify/remove transient components from objects

Not allowed operations:

- add/modify/remove objects from a frame that are not of types associated with
  the system
- add/remove persistent components that are not of types associated with the
  system


### Rewriting System

Rewriting system is a system that changes the structure of the graph. It is
typically activated on-demand as an action from the user. The system is used
_before_ compilation and therefore _before_ simulation.

Rewriting system typically creates, removes and modifies persistent structures
in the object memory.

Changes by the system are subject to constraints validation.


## Implementation

Systems are not yet fully implemented. Prototype of a system can be found in
the `SimulationSystem` protocol and `ControlBindingSystem` system that
populates control's values based on the control's target node.

Planned systems to be implemented:

- arithmetic expression parsing (currently hard-wired in a component)
- creation of implicit flows (currently part of the compiler)
- specific object type compilation, such as Stocks in the Stocks and Flows model

