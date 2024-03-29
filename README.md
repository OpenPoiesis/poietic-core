# Poietic Core

A modelling and simulation toolkit, primarily for systems thinking.

Function:

- Creation of models representable by graphs, such as systems dynamics models.
- Validation of models based on domain-specific constraints and types.
- History of editing changes with undo and redo functionality.

Focus and approach:

- The modelling process - _modelling the modelling_ and on 
  iterative and interactive design (once graphical user interface is available)
- Openness, sustainability and extensibility of the model data – The model format
  (either native or export/import) must be well documented, non-ambiguous and
  processable by third-party tools. It must allow extensibility of the modelling
  methodologies that are currently available.
- Approach from the "world is a graph" perspective, as opposed to "world is
  a set of equations and graph is just accidental" perspective. Gives us more
  freedom for further development and invention of new methods.

## Features

Current:

- Object graph with history of editing changes.
- Metamodel with object types, traits and constraints with the purpose of:
    - validation of model correctness according to a methodology of choice
    - containing of different kinds of systems thinking methodologies
    - development and evolution of the methodologies
- Non-destructive editing with undo and redo command.
- Simple arithmetic expressions (formulas).

See also [PoieticFlows](https://openpoiesis.github.io/PoieticFlows/documentation/poieticflows/)
– Stock and Flow modelling package.

Planned:

- API for GUI applications.
- Visual layout.
- Model (package) composition and comparison.
- Localisation/internationalisation.
- Ability to contain/integrate other meta-models:
    - Causal maps
    - SGBN and SBOL (design, composition, graph analysis, no simulation)

Out-of-scope:

- Performance. The system must be implemented in an understandable and
  transparent way first, before performance optimisation takes place.
- Human-modifiable textual representation (DSL in textual form) of the design
  and interpretation of such representation. In other words: No purely
  human-oriented modelling language. Textual DSL is a distraction and diversion
  from one of the main objectives, which is direct interactive experimentation
  with the design and its simulation. Also extensibility of a DSL might get
  too complex.

## Examples

Example models of of one of the methodologies can be found in the [Examples repository](https://github.com/OpenPoiesis/PoieticExamples).
Follow instructions how to run them in the documentation contained within the
repository.

## Documentation

- [PoieticCore](https://openpoiesis.github.io/PoieticCore/documentation/poieticcore/)
- [PoieticFlows](https://openpoiesis.github.io/PoieticFlows/documentation/poieticflows/)


## Development

This is a playful exploration.

More information about the development can be found in documents in the
[DevelopmentNotes](DevelopmentNotes) directory.

Further reading:

- [Requirements](DevelopmentNotes/Requirements.md) document in the
  DevelopmentNotes folder.
- [Technical Debt](DevelopmentNotes/TechnicalDebt.md) document in the
  DevelopmentNotes folder.

## Author

- [Stefan Urbanek](mailto:stefan.urbanek@gmail.com)
