# Runtime World

Types and functionality for a World – a runtime instance of a design with simulation related data,
simulation state, visual representations and other derived data.

## Overview

The design is a source of truth for the model. The world is the environment where the model becomes
alive for simulation, experimentation and interaction. It holds an entity for every object in the
plane, together with any additional entities your application creates. Setting a new plane
re-populates the world to match it.

Internally the World uses a light-weight Entity-Component-System (ECS) pattern with the
following concepts:

- **Entity** is representation of a thing, primarily a unique identity within the world.
  Some entities may represent a design object.
- **Component** is data attached to an entity. The entity can have only one component of a given type.
- **Relationship** is a link between entities. Relationships are special kinds of components,
  they can contain data as well.
- **System** is behaviour, a transformation, a function that reads and writes components,
  relationships and entities. Systems are run in a schedule.

- Note: The reason why ECS is used in this library is based rather on data modelling aspect, not
  performance. ECS here enables data-oriented thinking, modelling flexibility and extensibility.

World state is typically updated by systems (``System``, ``World/run(schedule:)``) but might be
changed directly by an application. You use systems and schedules for something that does
regular work, usually substantial with many transformations. Direct manipulation with the world is
done when the unit of change is small, very specific and non-extensible. For example placing or
dragging a visual object through user interface.


## Entities

Entities are representations of things, they are runtime objects in the world. There are two kinds
of entities: entities representing design objects and application entities.

The entities that represent design objects are spawned automatically by ``World/setPlane(_:)``. They
have ``RuntimeEntity/objectID`` associated with them, which links them to their original in the
design plane. In-reverse, entities for a design object can be looked up with
``World/entity(_:)-(ObjectID)``. You can work with design object entities in the same way as with
any other entity, only difference is that their lifecycle is managed by the world.

The application entities are spawned (``World/spawn(_:)->RuntimeEntity``) and managed by you. Some
examples of application entities:

- Simulation information
- Visual representations of design entities, such as diagram blocks or connectors
- Simulation result data
- Interaction state and temporary visual objects that exist during interactive preview

Example of spawning an entity:

```swift
// Illustrative components for a simple population model —
// these are not part of PoieticCore; define your own.
struct Population: Component { var count: Int }
struct BirthRate: Component { var perYear: Double }
struct PredatesOn: Relationship { static var targetRemovalPolicy: RelationshipRemovalPolicy = .remove }

let world = World(design: design)
world.setPlane(plane)

let rabbits = world.spawn(
    Population(count: 100),
    BirthRate(perYear: 2.5),
)
let wolves = world.spawn(
    Population(count: 10),
    BirthRate(perYear: 1),
)

wolves.relate(PredatesOn(), to: rabbits)
```

### Design Object Entities

Runtime entities representing design objects are special. The world manages their lifecycle and
keeps an index between object ID and an entity that represent that object. The link through
object ID from design object entities is the one deliberate convenience over typical pure ECS.

When a first plane is set with ``World/setPlane(_:)``, the world:

1. Spawns one entity for each design object.
2. Populates internal mapping between the two representations.
3. All entities will be tagged with ``ObjectTouched`` component, because they are new.


You can attach/remove components on design object entities, spawn your own entities.
Use the world as needed.

Setting a new plane re-populates the world:

1. De-spawns entities that represent objects that are no longer in the new plane.
2. Spawns entities for new objects.
3. Updates internal mapping between entities and design objects.
4. New objects and existing objects with new snapshot versions (same `objectID`,
  new `snapshotID`) will be tagged ``ObjectTouched``.
5. Old objects (same `objectID`, same `snapshotID`) will be left untouched.

You can query for the ``ObjectTouched`` flag to synchronise other, derived information.

Common use patterns:

- To get a runtime representation of design object: ``World/entity(_:)-(ObjectID)``
- To get a design object or an object ID of an entity that represents a design object:
   ``RuntimeEntity/designObject`` and ``RuntimeEntity/objectID`` respectively.

```swift
    let design: Design     // Assuming this exists
    let plane: DesignPlane // Assuming this exists. It can for example be design.currentPlane

    let world: World = World(design: design)

    // Set the current plane and spawn entities representing the design objects in the plane.
    world.setPlane(plane)

    for object in plane.filter(trait: .Formula) {
        guard let formula: String = object["formula"],
              let expression = try? ExpressionParser.parse(string: formula)
        else { continue }

        // Get an entity representing the design object with a formula.
        guard let entity = world.entity(object.objectID) else { continue }
        
        entity.setComponent(
            ParsedExpressionComponent(expression: expression)
        )
    }
```

## Relationships

Entities can be related to each other through relationships – special kinds of components that might
contain data. Relationships differ from components in that they have a target entity, they
can specify a policy what to do when the target is removed and there is a bi-directional index
computed for them. Examples of relationships: parent-child, memberships, indicate representation.

Entities can be related to each other with ``RuntimeEntity/relate(_:to:)-(_,RuntimeID)`` and
unrelated with ``RuntimeEntity/unrelate(_:)``. 

Relationships are bi-directional: you can get outgoing ``RuntimeEntity/outgoing(_:)``
and incoming ``RuntimeEntity/incoming(_:)`` relationships for an entity. 

Provided relationship types:

- ``ChildOf`` – parent-child relationship, also conveniently accessible through
  ``RuntimeEntity/parent`` and ``RuntimeEntity/children``.
- ``RepresentationOf`` – indication that an entity is a representation of another. For example
  a visual diagram block or a pictogram is a representation of a design object entity.
- ``MemberOf`` – collection member relationship.
- ``Handles`` – connects visual handles to the entities they handle, for example linking a connector
   mid-point handle to the connector entity.
- ``Controls`` – relationship from a controller controls another entity, for example a visual slider
   controls a simulation parameter value.


### Cardinality 

Relationship types specify their cardinality. You can set multiple relationships of the same kind,
if the relationship cardinality ``Relationship/outgoingCardinality`` allows it.

When the cardinality is ``Cardinality/one``, setting a new relationship with
``RuntimeEntity/relate(_:to:)-(_,RuntimeID)`` if one of the same type already exists, replaces the
previous one. Convenience method ``RuntimeEntity/firstOutgoing(_:)`` gives you the single outgoing
relationship if it exists.

### Removal Policy

To assure integrity of the world, there must be no invalid relationships – relationships that point
to non-existing entities. Each relationship type specifies what to do when its target is removed
from the world with ``Relationship/targetRemovalPolicy``. Possibilities are:

- **remove** the relationship from the owning entity. For example, if a visual slider controls
  a value of another entity, and the controlled entity is removed, then we keep the slider, just
  disconnect it by removing the relationship.
- **despawn** the entity that owns the relationship. For example: if a parent
  (target of `ChildOf`) is despawned, then the child is despawned together with it.
- Cause **fatal error** and crash the application to prevent state with broken integrity. This
  policy is provided for convenience of an application developer, no built-in relationships use
  this.

Cardinalities and policies for target removal of provided relationships:

| Relationship | Cardinality | Target is Removed |
| --- | --- | --- |
| ``ChildOf`` | to-one | despawn owner |
| ``RepresentationOf`` | to-one | despawn owner |
| ``MemberOf`` | to-one | despawn owner |
| ``Handles`` | to-one | despawn owner |
| ``Controls`` | to-many | remove relationship |


## Systems and Schedules

Systems (``System``) are processes (functions) that act on entities in the world. They might read,
set, or remove components; create or remove relationships; spawn and despawn entities,
produce singletons, read/write files, etc. Systems are typically grouped
in schedules ``Schedule`` where they can be ordered and run in specific order.

Example of how to update a world with a system using ``System/update(_:)``:

```swift
    let world: World // Assuming this exists
    
    let system = ExpressionParserSystem(world)
    system.update(world)
```

The following examples use illustrative systems and schedules. They are not part of the PoieticCore
library – they represent systems you will define for your own domain. Example of setting up world
schedules with ``World/addSchedule(_:)`` and running them with ``World/run(schedule:)``:

```swift
    // Define schedule labels
    enum SimulationSchedule: ScheduleLabel { }

    let world: World // Assuming this exists

    world.addSchedule(Schedule(
        label: SimulationSchedule,
        systems: [
            GrowSystem.self,
            ReportSystem.self,
        ],
        order: [
            (GrowSystem.self, before: ReportSystem.self),
        ]
    ))

    try world.run(schedule: SimulationSchedule.self)
```

## Topics

### Types

- ``World``
- ``RuntimeEntity``
- ``Component``
- ``Relationship``
- ``RuntimeID``


### Relationships

- ``Relationship``
- ``ChildOf``
- ``MemberOf``
- ``RepresentationOf`` 
- ``Controls``
- ``Handles``

### Components

- ``HasNumericIndicator``
- ``IsSelected``
- ``NumericValueSample``
- ``NumericValueStats``
- ``ObjectSnapshotRef``
- ``ObjectTouched``
- ``ParsedExpressionComponent``

### Systems and Schedules

- ``System``
- ``SystemDependency``
- ``Schedule``
- ``ScheduleLabel``
- ``PlaneChangeSchedule``
- ``InteractivePreviewSchedule``
- ``SimulationSchedule``
- ``InternalSystemError``

### Internal Storage

- ``ComponentStorageProtocol``
- ``ComponentSet``


