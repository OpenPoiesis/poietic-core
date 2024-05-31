//
//  Metamodel.swift
//
//
//  Created by Stefan Urbanek on 07/06/2023.
//

public struct Metamodel {
    private var _traits: [String:Trait]
    private var _types: [String:ObjectType]
    public private(set) var constraints: [Constraint]

    public var traits: [Trait] { Array(_traits.values) }
    public var types: [ObjectType] { Array(_types.values) }

    
    public init(traits: [Trait] = [],
                types: [ObjectType] = [],
                constraints: [Constraint] = []) {
        _traits = [:]
        for trait in traits {
            _traits[trait.name] = trait
        }
        
        _types = [:]
        for type in types {
            _types[type.name] = type
        }
        
        self.constraints = constraints
        
    }
    
    public init(domains: [Domain]) {
        self.init()
        for domain in domains {
            include(domain)
        }
    }
    
    public func trait(name: String) -> Trait? {
        return _traits[name]
    }
    
    public func objectType(name: String) -> ObjectType? {
        return _types[name]
    }
    
    private mutating func add(trait: Trait) throws {
        self._traits[trait.name] = trait
    }
    private mutating func add(type: ObjectType) throws {
        self._types[type.name] = type
    }
    
    /// Include a domain in the metamodel.
    ///
    /// If the new domain contains traits or types with names that
    /// already exist in the metamodel, the newly included will replace
    /// the existing ones.
    ///
    public mutating func include(_ domain: Domain) {
        for trait in domain.traits {
            self._traits[trait.name] = trait
        }
        for type in domain.objectTypes {
            self._types[type.name] = type
        }
        
    }

}

/// Object describing a design model.
///
/// The metamodel is the ultimate source of truth for the model domain and
/// should contain all named concepts that can be described declaratively. The
/// main components of the metamodel are:
///
/// - Object types – list of types of objects that are allowed for the domain
/// - Components - list of components that can be assigned to the objects
/// - Queries - list of predicates and queries to provide domain specific view
///   of a design and of the design graph.
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
///  - SeeAlso: ``Design/validate(_:)``, ``Design/accept(_:appendHistory:)``
///
public final class Domain {
    /// Name of the domain.
    ///
    /// The metamodel name is used for persistence.
    ///
    /// - SeeAlso: ``registerMetamodel(_:)``
    ///
    public let name: String
    
    /// List of components that are available within the domain described by
    /// this metamodel.
    public let traits: [Trait]

    /// List of object types allowed in the model.
    ///
    public let objectTypes: [ObjectType]
    
    /// List of constraints.
    ///
    /// Constraints are validated before a frame is accepted to the design.
    /// Design must not contain stable frames that violate any of the
    /// constraints.
    ///
    public let constraints: [Constraint]

    /// Create a new metamodel.
    ///
    /// - Parameters:
    ///   - traits: List of traits used or possible in the metamodel.
    ///   - objectTypes: List of object types validated by the metamodel.
    ///   - constraints: List of constraints that are used for design
    ///     validation.
    ///
    ///  - SeeAlso: ``Design/validate(_:)``
    ///
    public init(name: String,
                traits: [Trait] = [],
                objectTypes: [ObjectType] = [],
                constraints: [Constraint] = []) {
        self.name = name
        self.traits = traits
        self.objectTypes = objectTypes
        self.constraints = constraints
    }
    
    
    public func objectType(name: String) -> ObjectType? {
        return objectTypes.first { $0.name == name}
    }
}

extension Domain {
    /// A concrete metamodel without any specification.
    ///
    /// Used for testing and playground purposes.
    ///
    /// Each application is expected to provide their own domain specific metamodel.
    public static let Empty = Domain(
        name: "Empty",
        traits: [],
        objectTypes: [],
        constraints: []
    )

    /// Metamodel with some basic object types that are typical for multiple
    /// kinds of designs.
    ///
    public static let Basic = Domain(
        name: "Basic",
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
        constraints: []
    )
}
