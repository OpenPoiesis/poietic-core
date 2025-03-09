# Metamodel and Types

Metamodel defines types of the design objects and constraints that the design
must satisfy to be considered valid within a modelled problem domain.

## Overview

Metamodel represents a problem domain, methodology or a combination of both.
The metamodel defines which types of objects the domain considers and
what are the constraints or structural rules. The design objects must conform
to the defined types and satisfy the constraints for the design to be valid
within the problem domain.

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
    static let FlowRate = Trait(
        name: "FlowRate",
        attributes: [
            Attribute("priority", type: .int)
        ]
    )
}
```

Secondly we define object types which also specify structural type – whether
it is an edge or a node type. Some common traits are provided, such as
``Trait/Name`` for objects that are named, ``Trait/Formula`` for objects
that hold an arithmetic formula and ``Trait/DiagramNode`` for objects
that can be represented diagramatically.

```swift
extension ObjectType {
    // Node types
    static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        traits: [.Name, .Formula, .Stock, .DiagramNode],
    )
    static let FlowRate = ObjectType(
        name: "FlowRate",
        structuralType: .node,
        traits: [.Name, .Formula, .FlowRate, .DiagramNode]
    )
    // Edge types
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: .edge
    )
    static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: .edge,
    )
}
```

Once we have object types defined, we can assemble the metamodel:


```swift
public static let StockFlow = Metamodel(
    name: "StockFlow",
    traits: [ .Stock, .FlowRate ],
    types: [
        .Stock, .FlowRate,  // Nodes
        .Flow, .Parameter   // Edges
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

- ``ConstraintChecker``
- ``Constraint``
- ``DesignIssue``
- ``DesignIssueCollection``
- ``DesignIssueConvertible``
- ``ObjectTypeError``
- ``RejectAll``
- ``AcceptAll``
- ``ConstraintViolation``
- ``UniqueProperty``
- ``ConstraintRequirement``
- ``EdgeEndpointRequirement``
- ``ObjectTypeErrorCollection``

### Edge Rules

- ``EdgeRule``
- ``EdgeCardinality``
- ``EdgeRuleViolation``

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

