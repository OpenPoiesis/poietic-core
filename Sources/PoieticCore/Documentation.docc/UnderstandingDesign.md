# Understanding Design Objects and Frames

Containment and management of design objects and their history.

## Overview

Design is a collection of objects structured as a directed graph with an
optional explicit single parent-child hierarchy. Design represents creator's
idea or a model and its historical evolution. Each state – version snapshot –
of the design is represented by a ``Plane``.

![Design-Frame-Object composition](design-frame-object)

Each object is uniquely identified by an ID. Version of an object is
``ObjectSnapshot``, which contains object's properties. When working with
the design, the object ID is the primary object handle.


Each design is assigned a ``Metamodel``, which defines types of objects
``ObjectType`` and constraints ``Constraint``.

## Topics

### Object

- ``ObjectSnapshot``
- ``ObjectProtocol``
- ``ObjectID``
- ``ObjectSnapshotID``
- ``Topology``
- ``TopologyType``
- ``Selection``

### Design and Version Frames

- ``Plane``
- ``DesignPlane``
- ``PlaneID``
- ``PlaneValidationError``
- ``StructuralIntegrityError``

### Changes and Versions

- ``TransientPlane``
- ``TransientObject``

### Value and Variant

- ``Variant``
- ``VariantAtom``
- ``VariantArray``
- ``ValueType``
- ``ValueError``
- ``AtomType``
- ``Point``
