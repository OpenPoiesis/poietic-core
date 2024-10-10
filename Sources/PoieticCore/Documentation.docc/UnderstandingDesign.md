# Understanding Design Objects and Frames

Containment and management of design objects and their history.

## Overview

Design is a collection of objects structured as a directed graph with an
optional explicit single parent-child hierarchy. Design represents creator's
idea or a model and its historical evolution. Each state – version snapshot –
of the design is represented by a ``Frame``, which is somewhat analogous
to a movie frame.

![Design-Frame-Object composition](design-frame-object)


Each object is uniquely identified by an ID. Version of an object is
``ObjectSnapshot``, which contains object's properties. When working with
the design, the object ID is the primary object handle.


Each design is assigned a ``Metamodel``, which defines types of objects
``ObjectType`` and constraints ``Constraint``.


## Topics

### Object

- ``ObjectSnapshot``
- ``ObjectID``
- ``StructuralComponent``
- ``StructuralType``
- ``SnapshotID``
- ``ChildrenSet``

### Design and Version Frames

- ``Frame``
- ``StableFrame``
- ``MutableFrame``
- ``FrameID``
- ``VersionState``
- ``FrameConstraintError``

### Value and Variant

- ``Variant``
- ``VariantAtom``
- ``VariantArray``
- ``ValueType``
- ``ValueError``
- ``AtomType``
- ``ID``
- ``Point``

### Component

- ``Component``

