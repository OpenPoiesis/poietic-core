# Deign

Containment and management of design objects and their history.

## Overview

Design is a container representing a model, idea or a document with their
history of changes.

Design comprises of objects, heir attributes and their relationships which
which comprise an idea from a problem domain described by a Metamodel.
The _Metamodel_ defines types of objects, constraints and other properties
of the design, which are used to validate design's integrity.

## Topics

### Design and Version Frames

- ``Design``
- ``Frame``
- ``StableFrame``
- ``MutableFrame``
- ``FrameID``
- ``IdentityGenerator``
- ``SequentialIDGenerator``
- ``VersionState``
- ``FrameValidationError``

### Object

- ``ObjectSnapshot``
- ``ObjectID``
- ``SnapshotID``
- ``StructuralComponent``
- ``StructuralType``
- ``ChildrenSet``
- ``ObjectProtocol``

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
- ``ComponentSet``

