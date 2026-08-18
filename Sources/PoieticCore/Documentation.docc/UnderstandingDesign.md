# Understanding Design Objects and Planes

Containment and management of design objects, changes and their history.

## Overview

Design represents modeller's idea or a model and its historical evolution with multiple version
snapshots. Design is a collection of objects, their attributes and relationships.


### Objects

Every object ``ObjectSnapshot`` has a single identity – its object ID. The object ID is assigned
during object's creation and stays the same for the object's entire life, until the object is
removed from the design. Each change to the object produces a new snapshot, a frozen copy of the
object at that moment,  with its own snapshot ID. The object ID (``ObjectSnapshot/objectID``)
tells us "which object is this?"; the snapshot ID  (``ObjectSnapshot/snapshotID``) tells us
"which version of it is this?".

An object can be a node, an edge, unstructured (stand-alone) or an ordered set
– that is its ``Topology``. Separately objects might have a parent-child hierarchy.

Object is the main component of a model. Simulation is created from objects and their attributes.
Some of the objects might have a visual representation, for example a block with a pictogram for a
node or a connector arrow for an edge in a diagram.

See:

- Object creation: ``TransientPlane/create(_:objectID:snapshotID:topology:parent:children:attributes:)``
- Change object: ``TransientPlane/mutate(_:)`` then ``TransientObject``
- Remove object: ``TransientPlane/removeCascading(_:)``

### Editing and Transactions

``DesignPlane`` represents a design version snapshot - an immutable design state at a point in the
model's history. You create a plane with ``Design/createPlane(deriving:id:)``, then make changes
to it and its objects, then accept it with ``Design/accept(_:appendHistory:)``. When you try to
accept the plane, it is validated for structural integrity as required by the ``Design/metamodel``.

Users can edit a model which contains errors, and is therefore in a semantically broken state. 
Models with errors can not be simulated, but the user should be aware of the errors.
Just as you can write syntactically invalid code – you can not run it, but you can keep editing.
In your domain model implementation you translate and store user errors with
``RuntimeEntity/appendIssue(_:)`` and retrieve them from ``RuntimeEntity/issues``, so that
they can be shown to the user through the interface.

- Important: User errors should never result in structural integrity errors.

Example (assumes existence of `Stock` and `Flow` object types):

```swift
    let design: Design // Assume this exists
    let trans = design.createPlane()
    
    // Create nodes
    
    let kettle = trans.create(ObjectType.Stock,
                              topology: .node,
                              attributes: ["name": "kettle", "formula": "100"])
    let glass = trans.create(ObjectType.Stock,
                             topology: .node,
                             attributes: ["name": "glass", "formula": "0"])
    let pour = trans.create(ObjectType.FlowRate,
                            topology: .node,
                            attributes: ["name": "pour", "formula": "10"])
    
    // Connect nodes: Stock --(Flow)--> FlowRate --(Flow)--> Stock
    
    trans.create(ObjectType.Flow, topology: .edge(kettle.objectID, pour.objectID))
    trans.create(ObjectType.Flow, topology: .edge(pour.objectID, glass.objectID))
    
    // Accept the transient plane and make a stable plane
    
    let newPlane = try design.accept(trans)
    
    // Now the design.currentPlane is the newly created plane
    
```

To make changes to existing objects:

```swift
    let selectedObject: ObjectID // Assuming this exists, for example object ID of kettle from above
    
    guard let currentPlane = design.currentPlane else { /* fail */ }
    let trans = design.createPlane(deriving: currentPlane)
    let object = trans.mutate(selectedObject)
    object["formula"] = "200"
    let changedPlane = try design.accept(trans)
```

### Experimentation with History and Alternatives

One of the core principles of the library is to allow experimentation without risks. Each change
results in a new ``DesignPlane``, while keeping previous planes to which the user can come back. Plane can be
derived (branched) from an existing plane or a new empty plane can be created. The design stores all
the planes indefinitely, until requested to be removed (``Design/removePlane(_:)``.

There is one out-of-the-box mechanism for chronological ordering of the planes: the undo/redo stack
in the design. Planes can be appended to the stack using ``Design/accept(_:appendHistory:)`` with
`appendHistory` being `true` (default). Then your application can move through the history with
``Design/undo(to:)`` and ``Design/redo(to:)``. Planes can be added to the design out-of-history,
with application or user specific sequence or a timeline.

![Design-Frame-Object composition](design-frame-object)

Your application does not have to follow the built-in timeline. The application can instantiate any
plane in the world with ``World/setPlane(_:)``, so the users can experiment with it. 
A user (modeller) can compare planes either by switching between them or running multiple worlds in
parallel.

- Note: The library does not yet provide provenance of planes: which plane is derived from which.

### Metamodel

Each design follows rules specified by a ``Metamodel``. The metamodel specifies which types of objects
(``ObjectType``) are valid within given problem domain, and how the model is validated.


## Topics

### Design and Version Planes

- ``Design``
- ``DesignPlane``
- ``Plane``
- ``PlaneID``
- ``PlaneValidationError``
- ``StructuralIntegrityError``

### Changes and Versions

- ``TransientPlane``
- ``TransientObject``

### Object

- ``ObjectSnapshot``
- ``ObjectProtocol``
- ``ObjectID``
- ``ObjectSnapshotID``
- ``Topology``
- ``TopologyType``
- ``Selection``

### Value and Variant

- ``Variant``
- ``VariantAtom``
- ``VariantArray``
- ``ValueType``
- ``ValueError``
- ``AtomType``
- ``Point``

### Internal Representations

- ``IdentityManager``
- ``DesignEntityID``
- ``DesignEntityType``
- ``ObjectBody``
