# Poietic

A modelling and simulation toy toolkit for systems thinking and systems dynamics.

Function:

- Creation and iterative design of systems dynamics models.
- Simulation of systems dynamics models.

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

- [Stock and Flow](https://en.wikipedia.org/wiki/Stock_and_flow) model
    - Implemented nodes: Stock, Flow, Auxiliary, Graphical Function
    - Stocks can be either non-negative or can allow negative values
    - Included [Euler](https://en.wikipedia.org/wiki/Euler_method) and [RK4](https://en.wikipedia.org/wiki/Runge–Kutta_methods) solvers
- Simple arithmetic expressions (formulas)
    - Built-in functions: abs, floor, ceiling, round, power, sum, min, max
- Whole editing history is preserved.
- Editing is non-destructive and can be reversed using undo and
  redo commands.
- Exports:
    - [Graphviz](https://graphviz.org) dot files.
    - Export to CSV.
    - Charts to [Gnuplot](http://gnuplot.info)
  
Planned:

- More useful built-in functions and variables for the Stock and Flow model.
- Sub-systems.
- API for GUI applications.
- Visual layout.
- Model composition.
- Tabular (relational) representation of the model.
- Localisation/internationalisation.
- Ability to contain/integrate other meta-models:
    - Causal maps
    - SGBN and SBOL (design, composition, graph analysis, no simulation)
- Ability to invent and integrate other meta-models or to extend current
  meta-model(s).

Out-of-scope:

- Performance. The system must be implemented in an understandable and
  transparent way first, before performance optimisation takes place.
- Human-modifiable textual representation (DSL in textual form) of the design
  and interpretation of such representation. In other words: No purely
  human-oriented modelling language. Textual DSL is a distraction and diversion
  from one of the main objectives, which is direct interactive experimentation
  with the design and its simulation. Also extensibility of a DSL might get
  too complex.

## Demos

Example models can be found in the [Demos repository](https://github.com/OpenPoiesis/Demos).

## Documentation

- [PoieticCore](https://openpoiesis.github.io/PoieticCore/documentation/poieticcore/)
- [PoieticFlows](https://openpoiesis.github.io/PoieticFlows/documentation/poieticflows/)

## Command-line Tool

At the moment, the only user-facing interface is a command-line tool called
``poietic``. The available commands are:

```
  new                     Create an empty design.
  info                    Get information about the design
  list                    List all nodes and edges
  describe                Describe an object
  edit                    Edit an object or a selection of objects
  import                  Import a frame bundle into the design
  run                     Run a model
  write-dot               Write a Graphviz DOT file.
  metamodel               Show the metamodel
```

The edit subcommands are:

```
  set                     Set an attribute value
  undo                    Undo last change
  redo                    Redo undone change
  add                     Create a new node
  connect                 Create a new connection (edge) between two nodes
```

Use `--help` with the desired command to learn more.


### Pseudo-REPL

Think of this tool as [ed](https://en.wikipedia.org/wiki/Ed_(text_editor)) but
for data represented as a graph. At least for now.

The tool is designed in a way that it is by itself interactive for a single-user. 
For interactivity in a shell, set the `POIETIC_DATABASE` environment variable to
point to a file where the design is stored.

Example session:

```
export POIETIC_DATABASE="MyDesign.poietic"

poietic new
poietic info

poietic edit add Stock name=water formula=100
poietic edit add Flow name=outflow formula=10
poietic edit connect Drains water outflow

poietic list formulas

poietic edit add Stock name=unwanted
poietic list formulas
poietic edit undo

poietic list formulas

poietic run
```


## Development

This is a sketch of a toy.

More information about the development can be found in documents in the
[DevelopmentNotes](DevelopmentNotes) directory.

Further reading:

- [Requirements](DevelopmentNotes/Requirements.md) document in the
  DevelopmentNotes folder.
- [Technical Debt](DevelopmentNotes/TechnicalDebt.md) document in the
  DevelopmentNotes folder.

## Author

- [Stefan Urbanek](mailto:stefan.urbanek@gmail.com)
