# Metamodel

The metamodel defines model concepts, more specifically: types of objects in the
design, their components and constraints.

## Current Implementation

The metamodel is currently implemented as a programming language – Swift object
type. The main reason is accessibility of the metamodel concepts in the 
programming language. For example, if we have an object type named _Stock_ we
want to access it by that name as a symbol in the programming language:

```swift
        graph.createNode(FlowsMetamodel.Stock,
                         name: "source",
                         components: [FormulaComponent(expression:"1000")])
```

Here the `FlowsMetamodel.Stock` refers to a `Stock` object type in the
metamodel for _Stock and Flow_ domain model.

Specific problem domain models are expected to subclass the metamodel type
and define the model concepts as static (class) variables of the type.

Advantages of the current implementation

- Named concepts in the programming language
- No need to special context passing

Shortcomings of the current implementation:

- Not possible to compose multiple metamodels together
- Not possible to alter metamodels

The composability is an important required feature of the project.

## Requirements

The requirements for the metamodel subsystem are:

- Ability to compose - merge multiple metamodels together, with sensible
  conflict resolution.
- Integration of metamodel changes with the object memory so that changes
  in the metamodel would trigger conceptual integrity checks of the memory.
- Ability to access named metamodel concepts as symbols in the host programming
  language.
  
## Proposal

The contents of the metamodel would change from being a type (static) content to
instance content. The metamodel would be associated as an instance of a final
(non-extensible) Metamodel type. The instance variables are:

- `components: [Component.Type]` – list of components that are available within
  the problem domain. Object types must not contain components not in this list.
- `objectTypes: [ObjectType]` – list of object types that are possible in the
  domain. The design in the domain defined by this metamodel must not contain
  objects of types that are not in this list.
- `constraints: [Constraint]` – list of constraints that must be satisfied.

Functions:

- `objectType(name: String) -> ObjectType?` – get an object type by name
- `componentType(name: String) -> Component.Type?` – get a component by name

Mutating functions that trigger validation of the memory:

- `addObjectType(_ type: ObjectType)` – add a new object type. The new object
  type must contain only components
  defined in the list of components.
- `removeObjectType(_ type: ObjectType)` – remove the object type from the
  metamodel.
- `addComponentType(objectType: ObjectType, componentType: Component.Type)` –
  add a component type to the list of components of an object type. The
  component type must exist in the list of components of the metamodel.
 
  
### Usage
  
With the design of a metamodel as an instance, all systems must now get a
metamodel context. Systems that are already using frames or a memory already
have access to the metamodel. Systems that are not using frames or a memory,
such as _Solver_ in the _PoieticFlows_ library must now get an immutable
instance of the metamodel.

## Complications and Further Questions

- How to deal with the history – what to do with frames before a metamodel
  change?


