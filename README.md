# Poietic Core

A foundation for building virtual laboratories – interactive modelling and simulation applications.
An exploration of _modelling the modelling_.

> _Can you draw the model diagrammatically – as boxes and arrows, where not only the boxes but
> also the connections between the boxes are meaningful content?_

If the answer to the above question is _yes_, then this library might be suitable for you.

The library's approach is the _"world is a graph"_ perspective, as opposed to _"world is
a set of equations and graph is just accidental"_ perspective. Learn more from the
[package documentation](https://openpoiesis.github.io/poietic-core/documentation/poieticcore/).

## Application Examples

- [Poietic Tool](https://github.com/OpenPoiesis/poietic-tool) – A command-line tool for editing
  and running Stock and Flow models.
- [Poietic Playground](https://github.com/OpenPoiesis/poietic-playground) – A CAD-like application
  where you can visually edit, inspect and run models.

Models to be used by the applications:

- [Examples repository](https://github.com/OpenPoiesis/PoieticExamples)

## Feature Overview

- **Design** is the source of truth.
- **Planes** are snapshots of history or alternative versions of the design.
- **World** is the running instance for experimentation. Lightweight ECS with a focus on data
  modelling and extensibility (not performance).
- **Metamodel** defines problem domain constraints.
- **Foreign Interfaces** for import/export and persistence.
- **Arithmetic expression** parsing and evaluation.

## Documentation

- [PoieticCore](https://openpoiesis.github.io/poietic-core/documentation/poieticcore/)

Related packages:

- [PoieticFlows](https://openpoiesis.github.io/poietic-flows/documentation/poieticflows/)
- [Diagramming](https://openpoiesis.github.io/poietic-diagram/documentation/diagramming/)
  – Package for creating diagrammatic representations of models.

## Contributing

_All humans are more than welcome to contribute to the project._

Read more in the [Contribution Policy](CONTRIBUTING.md) file.

## Author

- [Stefan Urbanek](mailto:stefan.urbanek@gmail.com)
