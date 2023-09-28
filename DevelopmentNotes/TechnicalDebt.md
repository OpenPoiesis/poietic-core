# Technical Debt

This document describes details about known technical debt.

Last update: 2023-09-28

## Introduction

The project is going through an initial prototyping phase. The primary goal is
to experiment with intended functionality and experiment with potential ways
of how to satisfy the project requirements. Focus on one aspect of the project
might cause a debt on another aspect of the project.


It is important to note that non-user facing requirements are as important
for this project as the user-facing requirements. For example, the
"Extensibility and evolvability" or "Openness and repairability" are
are no less important than the user interaction Even-though they are not visible
to the end user they exist for the continuation of the project. Conflicts
between end-user functionality and, for example evolvability, are expected
and they help to refine the architecture of the project.

## Technical Debt Markers

When a conscious decision was made not to finish or to quickly put together
a functionality so that "it just works" is usually marked in the code.

- `TODO:` marks known changes to the functionality which are desired yet
  might not be as important for the time of the writing.
- `FIXME:` marks a code that is known not to work in all required circumstances
  or known to cause harmful effects.
  
Additional annotation:

- `[EXPERIMENTAL]` – the code requires a review, deeper thought or even a 
  proper design. It was written as a prototype to try out some new
  functionality.
- `[FRAGILE]` – the code works only in few, less than intended, 
  usually very specific cases, it should be revised and changed to cover
  more use-cases.
- `[IMPORTANT]` – more attention should be given to this piece of code,
  as the functionality is crucial to the overall functioning of the whole
  system.
- `[OBSOLETE]` – code that is now known to be relevant in some previous
  iterations of the project, however it should be either updated or removed.
- `[REVIEW]` – code needs proper review and potentially testing.
- `[REFACTORING]` – temporary marker of a code during a refactoring. These
  should go away once the refactoring is done.
  
## Known Debt

### Object Creation

*Problem:* There are multiple ways how the objects in the memory can be created.

*Requirement:* There should be only one.

Locations and relevant code:

- `ObjectSnapshot`: `init(...)`
- `ObjectMemory`: `createSnapshot(...)`, `allocate*(...)`
- `MutableFrame`: `create(...)`, `mutableObject(...)`
- `MutableGraph`: `createNode(...)`, `createEdge(...)`
- `VersionState`
- foreign interface
- memory archival

Possible directions:

- Alternative A: Make `ObjectSnapshot.init()` private, create objects through
  `ObjectMemory.allocate(...)` and `ObjectMemory.initialize()`
- Alternative B: `ObjectMemory.allocate(...)` returns an "unstable object"
  reference bound to the object memory and/or/maybe a frame. Then
  allow operations directly on the reference and make it stable on
  `ObjectSnapshot.initialize()` which will invalidate the unstable reference
  and return the final direct snapshot reference.

### Metamodel

**Problem:** The metamodel is a type.

**Requirement:** The metamodel should be an instance that can be composed.

Reason for a type is so that during prototyping the metamodel elements
can be accessed as symbols in the host programming language (Swift)

Locations:

- `Metamodel` in `PoieticCore` library
- `FlowsMetamodel` in `PoieticFlows` library
- usage of `Metamodel` in `Compiler`, `StockFlowView`
- usage of `Metamodel` in `PoieticTool` executable

Possible directions:

- Convert Metamodel to be an instance
- Where it is necessary or convenient to use direct metamodel symbols, use
  a metamodel view or some context/wrapper with dynamic lookup of the
  metamodel components. (This is actually the correct dynamic way)


### Object Mutation

**Problem:** Object mutation has no clear boundaries and can be considered
unsafe in many places.

**Complication:** It is unsafe to make any part of the code to be used in a multi-threaded
environment.

**Requirement:** Make it explicit who and where can mutate objects and what
happens on mutation.

When we talk about mutation in this project we do not mean necessarily the same
as the mutation in the host programming language (Swift). Mutations are bundled
in a transaction that affects the whole version frame. By mutating an object
we are mutating the whole frame.

Locations:

- `MutableFrame`, especially `mutableObject(...)`
- `ObjectMemory`
- `ObjectSnapshot`

Possible directions:

- Distinguish between object references: mutable and immutable
- Do not expose ObjectSnapshot directly - only through the references

