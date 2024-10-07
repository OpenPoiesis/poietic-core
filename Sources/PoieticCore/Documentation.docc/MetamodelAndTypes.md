# Metamodel and Types

Metamodel defines types of the design objects and constraints that the design
must satisfy to be considered valid.

## Overview

Metamodel represents a problem domain. The metamodel defines which types of
objects the domain considers and what are the constraints or structural rules.
The design objects must conform to the defined types and satisfy the constraints
for the design to be valid within the problem domain.

Example: A domain for modelling systems dynamics using stock and flows might
consider node types _Stock_, _Flow_ and and _Drains_, _Fills_ edge types.

First we define traits – groups of attributes:

```swift
extension Trait {
    static let Stock = Trait(
        name: "Stock",
        attributes: [
            Attribute("allows_negative", type: .bool),
            Attribute("delayed_inflow", type: .bool),
        ]
    )
    static let Flow = Trait(
        name: "Flow",
        attributes: [
            Attribute("priority", type: .int)
        ]
    )
}
```

Secondly we define object types which also specify structural type – whether
it is an edge or a node type. Some common traits are provided, such as
``Trait/Name`` for objects that are named, ``Trait/Formula`` for objects
that hold an arithmetic formula and ``Trait/Position`` for objects
that can be represented diagramatically.

```swift
extension ObjectType {
    // Node types
    static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        traits: [.Name, .Formula, .Stock, .Position],
    )
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: .node,
        traits: [.Name, .Formula, .Flow, .Position]
    )
    // Edge types
    static let Drains = ObjectType(
        name: "Drains",
        structuralType: .edge
    )
    static let Fills = ObjectType(
        name: "Fills",
        structuralType: .edge,
    )
}
```

Once we have object types defined, we can assemble the metamodel:


```swift
public static let StockFlow = Metamodel(
    name: "StockFlow",
    traits: [ .Stock, .Flow ],
    types: [
        .Stock, .Flow,       // Nodes
        .Drains, .Fills,     // Edges
    ]
)
```

Metamodels typically contain constraints. For more information and some
examples see ``Constraint``.




## Topics

### Metamodel and Object Types

- ``Metamodel``
- ``ObjectType``
- ``Trait``
- ``Attribute``

### Constraints

- ``Constraint``
- ``ConstraintChecker``
- ``EdgeEndpointTypes``
- ``RejectAll``
- ``AcceptAll``
- ``ConstraintViolation``
- ``UniqueNeighbourRequirement``
- ``UniqueProperty``
- ``ConstraintRequirement``

### Common Components and Types

- ``Trait/Name``
- ``Trait/Documentation``
- ``Trait/Keywords``
- ``Trait/Note``
- ``Trait/DesignInfo``
- ``Trait/DesignInfo``
- ``ObjectType/DesignInfo``
- ``Trait/AudienceLevel``
- ``AudienceLevel``

### Other

- ``Variable``

