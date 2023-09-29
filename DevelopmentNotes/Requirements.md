#  Requirements

System to be designed:

> Set of libraries and tools for computer aided design of systems thinking
  models.

## System Concerns

### Purpose

1. Aid in visual design of a domain model (stock-flow, causal map, …).
2. Simulation of a model.
3. Comparison of different models or different versions of a model.
4. Composition of meta-models.
5. Aid in reasoning about a domain model by deriving/computing additional
   information from the model.
6. Creation of clear, understandable graphical representation of the domain model.

### Needs

**User-oriented needs**

1. User entered content – the creation – is holy.
    - The content should be preserved as-is and provided to the user in an
      understandable and processable form when asked for.
2. Ability to design a model interactively and iteratively.
    - User must be able to explore different model versions easily.
    - User must be able to revert its actions without losing any of entered
      content.
    - User must be able to see the evolution of the model.
3. User must be allowed to make mistakes without harm to the user and to the creation.
    - Alternative wording: User must be allowed to do experiments and to be playful.
    - User must know where they made a mistake.
    - User should receive a hint what to do to prevent the mistake,
      if possible.
      
**Creation-oriented needs**

4. Users creation should have assured durability and should not be locked-in.
   by a particular version of the system.
    - The persisted artefacts of user's creation must be stored in a format
      that is open and documented.
    - Inspection of the structure of stored archive should be reasonably
      possible with third-party tools that are not based on the Poietic System.
      [^1]

[^1]: For example a relational database storage or a directory with a collection
      of CSV files satisfies this requirement.

    
### Maintainability and Evolvability

1. Continuation of the system is an important feature.
2. It must be easy to add new object types and to extend objects with new
   components.
3. It must be possible to inspect the design during runtime.

**Principles governing the evolution of the system:**

4. The metamodel and the constraints must be explicit and their description must
   be available during runtime.
5. The system should be implemented in a transparent way and it should be
   reasonably easy to explain its functioning.
6. The system should not be tightly coupled with the programming language the
   system is implemented in.
    - It should be reasonably straightforward to rewrite the system or its
      subsystems in another programming language.
      

