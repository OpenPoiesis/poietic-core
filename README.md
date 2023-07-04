# Poietic

A modelling and simulation toy toolkit for systems dynamics.

Function:

- Creation and iterative design of systems dynamics models
- Simulation of systems dynamics models

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
    - Implemented nodes: Stock, Flow, Auxiliary
    - Stocks can be either non-negative or can allow negative values
    - Included [Euler](https://en.wikipedia.org/wiki/Euler_method) and [RK4](https://en.wikipedia.org/wiki/Runge–Kutta_methods) solvers
- Simple arithmetic expressions (formulas)
    - Built-in functions: abs, floor, ceiling, round, power, sum, min, max
- Export to [Graphviz](https://graphviz.org) dot files.
- Whole editing history is preserved.
- Editing is non-destructive and can be reversed using undo and
  redo commands.
  
Planned:

- More useful built-in functions and variables.
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

## Command-line Tool

At the moment, the only user-facing interface is a command-line tool called
``poietic``. The available commands are:

```
  new                     Create an empty design.
  info                    Get information about the design
  list                    List all nodes and edges
  describe                Describe an object
  edit                    Edit an object or a selection of objects
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
## Examples

Examples are coming.

One built-in example is a
[Lotka-Volterra](https://en.wikipedia.org/wiki/Lotka–Volterra_equations)
predator-prey model that can be created by the tool:

```
poietic new --include-demo
```

Inspect the model:

```
poietic list formulas
```


## Development

This is a hobby project. A toy.

It is still a prototype, a sketch if you like. Compare it to painter's canvas
at the beginning - rough outlines with a pencil.

Different parts reflect different stages and different understanding of the
problem and its implementation. As the understanding of the problem improves,
the parts are refactored. However, the primary focus right now is on having
some basic functionality of the whole system without seriously annoying the
users.

- Technical debt is marked with `TODO:` or with more serious `FIXME:`, production
  critical have the word `IMPORTANT` added.
- Implementation must be understandable, even for the cost of performance. Parts
  that might need optimisation must be separated and an abstraction layer
  must be provided while keeping the non-performant yet readable implementation
  as an option.

Principles:

- User entered content is holy. Should be preserved as-is and provided to the
  user in an understandable and processable form when asked for.
- User is allowed to make mistakes.

Error handling:

- There should be a strict distinction between a programming error and user error:
    - Programming errors must not happen at any cost, they are guarded by 
      preconditions and asserts. Programming errors are errors that prevent
      further continuation of the program in a meaningful and consistent way.
      Example: Errors with user input are not programming errors.
    - User errors must be handled and presented to the user.
- Errors should be descriptive and it is recommended that they are accompanied
  with a hint how to remove them.
- If there is a potential for multiple user errors, then as many errors should be
  gathered as possible and presented to the user.
- Context of the error must be included if known, for example an object that
  caused the error.

## Author

- [Stefan Urbanek](mailto:stefan.urbanek@gmail.com)
