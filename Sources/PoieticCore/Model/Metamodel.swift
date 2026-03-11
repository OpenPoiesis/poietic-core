//
//  Metamodel.swift
//
//
//  Created by Stefan Urbanek on 07/06/2023.
//

/// Defines the structural and semantic rules that a ``Design`` must conform to.
///
/// The Metamodel serves as the contract between the Modelling Domain (``Design``) and the
/// Simulation Domain (``World``). It defines:
///
/// ## Validation Levels
///
/// The design has two levels of design validity:
///
/// - **Constraint Validity**: Structural conformance defined by the Metamodel and checked by
///   ``ConstraintChecker``.
///   - All object types used in the design must be defined in the metamodel
///   - All objects must conform to their type's trait requirements
///   - All edges must satisfy edge rules
///   - All constraints must be satisfied
///
/// - **Semantic Validity**: Content domain-specific correctness, validated by modelling domain
///   systems.
///   - Examples: formula syntax, variable references, circular dependencies
///   - These may produce warnings/errors but don't prevent design editing and other usage by the
///     user.
///   - Metamodel is tangential to semantic validity.
///
/// An application is responsible for constraint validity of the design and should prevent further
/// manipulation of an invalid design.
///
/// ## Design Frame Acceptance
///
/// Before a ``DesignFrame`` is accepted into a ``Design``, it must pass constraint validation.
/// Frames that violate the metamodel are considered structurally invalid and should not be
/// persisted without repair. See ``Design/accept(_:appendHistory:)`` and ``ConstraintChecker``.
///
/// ## Metamodel Composition
///
/// Metamodels can be composed from multiple domain-specific metamodels using the
/// ``init(name:version:merging:)`` initialiser. When merging, later definitions override
/// earlier ones for traits, types, and constraints with the same name.
///
/// ## Example
///
/// ```swift
/// let metamodel = Metamodel(
///     name: "MyDomain",
///     version: SemanticVersion(1, 0, 0),
///     traits: [
///         Trait.Name,
///         Trait.Formula,
///         Trait.Position
///     ],
///     types: [
///         ObjectType.Stock,
///         ObjectType.Flow,
///         ObjectType.Parameter
///     ],
///     edgeRules: [
///         EdgeRule(type: ObjectType.Parameter, incoming: .many, outgoing: .many),
///         EdgeRule(type: ObjectType.Flow,
///                  origin: IsTypePredicate(ObjectType.Stock),
///                  target: IsTypePredicate(ObjectType.FlowRate),
///                  outgoing: .one,
///                  incoming: .one)
///     ],
///     constraints: [
///         Constraint(
///             name: "unique_names",
///             match: HasTraitPredicate("Name"),
///             requirement: UniqueProperty("name")
///         )
///     ]
/// )
/// ```
///
/// - SeeAlso: ``ConstraintChecker``, ``Design/accept(_:appendHistory:)``,
///   ``ObjectType``, ``Trait``, ``EdgeRule``, ``Constraint``
///
public final class Metamodel: Sendable {
    /// Name of the metamodel, for debug purposes.
    public let name: String?
    public let version: SemanticVersion?

    /// List of traits that are available within the metamodel.
    ///
    /// Object types can use only traits from this list.
    ///
    public let traits: [Trait]

    /// List of object types allowed in the model.
    ///
    /// Design objects conforming to this metamodel can be only of the types in this list.
    ///
    public let types: [ObjectType]
    
    /// List of constraints.
    ///
    /// Constraints are validated before a frame is accepted to the design.
    /// Design must not contain design frames that violate any of the
    /// constraints.
    ///
    public let constraints: [Constraint]

    public let edgeRules: [EdgeRule]
    
    /// Create a new empty metamodel.
    ///
    public init() {
        self.name = nil
        self.version = nil
        self.traits = []
        self.types = []
        self.constraints = []
        self.edgeRules = []
    }
    
    /// Create a new metamodel.
    ///
    /// - Parameters:
    ///   - name: Name of the metamodel.
    ///   - version: Version of the metamodel.
    ///   - traits: List of traits used or possible in the metamodel.
    ///   - types: List of object types validated by the metamodel.
    ///   - edgeRules: List of edge rules used for validation.
    ///   - constraints: List of constraints that are used for design validation.
    ///
    ///  - SeeAlso: ``ConstraintChecker``, ``EdgeRule``.
    ///
    public init(name: String? = nil,
                version: SemanticVersion? = nil,
                traits: [Trait] = [],
                types: [ObjectType] = [],
                edgeRules: [EdgeRule] = [],
                constraints: [Constraint] = []) {
        self.name = name
        self.version = version
        self.traits = traits
        self.types = types
        self.edgeRules = edgeRules
        self.constraints = constraints
    }
   
    /// Create a metamodel by merging multiple metamodels.
    ///
    /// If multiple traits, constraints and object types have the same name, then the later
    /// in the list will replace the former.
    ///
    public init(name: String? = nil, version: SemanticVersion? = nil, merging metamodels: Metamodel ...) {
        var traits: [Trait] = []
        var constraints: [Constraint] = []
        var types: [ObjectType] = []
        var edgeRules: [EdgeRule] = []
        
        self.name = name
        self.version = version
        
        for domain in metamodels {
            for trait in domain.traits {
                if let index = traits.firstIndex(where: { $0.name == trait.name }) {
                    traits[index] = trait
                }
                else {
                    traits.append(trait)
                }
            }

            for type in domain.types {
                if let index = types.firstIndex(where: { $0.name == type.name }) {
                    types[index] = type
                }
                else {
                    types.append(type)
                }
            }

            for constraint in domain.constraints {
                if let index = constraints.firstIndex(where: { $0.name == constraint.name }) {
                    constraints[index] = constraint
                }
                else {
                    constraints.append(constraint)
                }
            }
            // TODO: Make merging of edge rules smarter - avoid duplicates
            edgeRules += domain.edgeRules
        }

        self.traits = traits
        self.types = types
        self.constraints = constraints
        self.edgeRules = edgeRules
    }
    
    /// Selection of node object types.
    ///
    public var nodeTypes: [ObjectType] {
        types.filter { $0.structuralType == .node }
    }

    /// Selection of edge object types.
    ///
    public var edgeTypes: [ObjectType] {
        types.filter { $0.structuralType == .edge }
    }

    /// Selection of unstructured object types.
    ///
    public var unstructuredTypes: [ObjectType] {
        types.filter { $0.structuralType == .unstructured }
    }

    /// Get an object type by its name.
    ///
    /// Example:
    ///
    /// ```swift
    /// let metamodel = Metamodel.StockFlow
    ///
    /// let stockType = metamodel["Stock"]
    /// let flowType = metamodel["Flow"]
    /// ```
    public subscript(name: String) -> ObjectType? {
        return types.first { $0.name == name}
    }

    /// Get an object type by its name.
    ///
    /// Example:
    ///
    /// ```swift
    /// let metamodel = Metamodel.StockFlow
    ///
    /// let stockType = metamodel.objectType(name: "Stock")
    /// let flowType = metamodel.objectType(name: "Flow")
    /// ```
    public func objectType(name: String) -> ObjectType? {
        return types.first { $0.name == name}
    }
    public func hasType(name: String) -> Bool {
        return types.contains { $0.name == name}
    }
    public func hasType(_ type: ObjectType) -> Bool {
        return types.contains { $0 === type}
    }
    public func trait(name: String) -> Trait? {
        return traits.first { $0.name == name}
    }
}

