//
//  Metamodel.swift
//
//
//  Created by Stefan Urbanek on 07/06/2023.
//


/// Protocol for meta–models – models describing problem domain models.
///
/// The metamodel is the ultimate source of truth for the model domain and
/// should contain all named concepts that can be described declaratively. The
/// main components of the metamodel are:
///
/// - Object types – list of types of objects that are allowed for the domain
/// - Components - list of components that can be assigned to the objects
/// - Queries - list of predicates and queries to provide domain specific view
///   of the object memory and of the graph
///
/// Reasons for this approach:
///
/// - One source of truth.
/// - Abstraction from persistence, inspection (UI), scripting.
/// - Transparency and audit-ability of the domain model.
/// - Reflection.
/// - Fair compromise between model DSL and native programming language, while
///   providing some possibility of accessing some of the meta-model components
///   through the native programming language identifiers.
/// - Potentially, in the far future, the metamodel or its parts can be compiled
///   for better performance (which is out of scope at this moment).
///
/// The major use-cases of the reflection:
///
/// - Documentation.
/// - Provide information through tooling to the user about what can be created,
///   used, inspected.
/// - There are going to be multiple versions of the toolkit in the wild, users
///   can investigate the capabilities of their installed version of the toolkit.
///
/// - Note: Each application is expected to provide their own domain specific metamodel.
///
public final class Metamodel {
    /// List of components that are available within the domain described by
    /// this metamodel.
    public let traits: [Trait]

    /// List of object types allowed in the model.
    ///
    public let objectTypes: [ObjectType]
    
    // FIXME: Remove, move to a "named object"
    /// List of built-in variables.
    ///
    public let variables: [BuiltinVariable]
    
    /// List of constraints.
    ///
    /// Constraints are validated before a frame is accepted to the memory.
    /// Memory must not contain stable frames that violate any of the
    /// constraints.
    ///
    public let constraints: [Constraint]

    // TODO: Add named objects (objects that are required to exist)
    
    public init(traits: [Trait] = [],
                objectTypes: [ObjectType] = [],
                variables: [BuiltinVariable] = [],
                constraints: [Constraint] = []) {
        self.traits = traits
        self.objectTypes = objectTypes
        self.variables = variables
        self.constraints = constraints
    }
    
    public func objectType(name: String) -> ObjectType? {
        return objectTypes.first { $0.name == name}
    }
    
    /// Get a list of built-in variable names.
    ///
    /// This list is created from the ``Metamodel/variables`` list for
    /// convenience.
    ///
    public var variableNames: [String] {
        variables.map { $0.name }
    }

}

/// A concrete metamodel without any specification.
///
/// Used for testing and playground purposes.
///
/// Each application is expected to provide their own domain specific metamodel.
public let EmptyMetamodel = Metamodel(
    traits: [],
    objectTypes: [],
    variables: [],
    constraints: []
)

/// Metamodel with some basic object types that are typical for multiple
/// kinds of designs.
///
public let BasicMetamodel = Metamodel(
    traits: [
        Trait.Name,
        Trait.DesignInfo,
        Trait.Documentation,
        Trait.AudienceLevel,
        Trait.Keywords,
        Trait.BibliographicalReference,
    ],
    objectTypes: [
        ObjectType.DesignInfo,
    ],
    variables: [],
    constraints: []
)
