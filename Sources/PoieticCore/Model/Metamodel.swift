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
/// ## Design Plane Acceptance
///
/// Before a ``DesignPlane`` is accepted into a ``Design``, it must pass constraint validation.
/// Planes that violate the metamodel are considered structurally invalid and should not be
/// persisted without repair. See ``Design/accept(_:appendHistory:)`` and ``ConstraintChecker``.
///
/// ## Metamodel Composition
///
/// Metamodels can be composed from multiple domain-specific metamodels using the
/// ``init(name:version:merging:)`` initialiser. This is a simple composition method provided for
/// convenience. When merging multiple metamodels, the referenced items (object types, traits,
/// constraints) that share the same name must be of the same identity (same instances).
///
/// ## Example
///
/// The following example shows a minimal Stock-Flow domain metamodel. The `StockFlowDomain` enum
/// is a convenience namespace for the domain object types.
///
/// ```swift
///
/// enum StockFlowDomain {
///     static let Stock = ObjectType(
///         name: "Stock",
///         topologyType: .node,
///         traits: [
///             BasicDomain.Traits.Name,
///             BasicDomain.Traits.Position,
///             SimulationDomain.Traits.Formula,
///         ],
///     )
///     static let FlowRate = ObjectType(
///         name: "FlowRate",
///         topologyType: .node,
///         traits: [
///             BasicDomain.Traits.Position,
///             SimulationDomain.Traits.Formula,
///         ],
///     )
///     static let Fills = ObjectType(name: "Fills", topologyType: .edge)
///     static let Drains = ObjectType(name: "Drains", topologyType: .edge)
///     static let Parameter = ObjectType(name: "Parameter", topologyType: .edge)
/// }
///
/// let metamodel = Metamodel(
///     name: "StockFlow",
///     version: SemanticVersion(1, 0, 0),
///     traits: [
///         BasicDomain.Traits.Name,
///         BasicDomain.Traits.Position,
///         SimulationDomain.Traits.Formula,
///     ],
///     types: [
///         StockFlowDomain.Stock,
///         StockFlowDomain.FlowRate,
///         StockFlowDomain.Fills,
///         StockFlowDomain.Drains,
///         StockFlowDomain.Parameter,
///     ],
///     edgeRules: [
///         EdgeRule(type: StockFlowDomain.Parameter, incoming: .many, outgoing: .many),
///         EdgeRule(type: StockFlowDomain.Fills,
///                  origin: .isType(StockFlowDomain.FlowRate),
///                  target: .isType(StockFlowDomain.Stock),
///                  outgoing: .one,
///                  incoming: .one),
///         EdgeRule(type: StockFlowDomain.Drains,
///                  origin: .isType(StockFlowDomain.Stock),
///                  target: .isType(StockFlowDomain.FlowRate),
///                  outgoing: .one,
///                  incoming: .one),
///     ],
///     constraints: [
///         Constraint(
///             name: "unique_names",
///             match: .hasTrait("Name"),
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
    /// Constraints are validated before a plane is accepted to the design.
    /// Design must not contain design planes that violate any of the
    /// constraints.
    ///
    public let constraints: [Constraint]

    /// Edge rules that the design must satisfy to be valid.
    ///
    /// - Important: There must be at least one edge rule per edge type. To allow any edge
    ///   connections, add a rule similar to this example for each edge type:
    ///   ```swift
    ///   EdgeRule(type: MyEdgeType, incoming: .many, outgoing: .many),
    ///   ```
    ///
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
    ///   - edgeRules: List of edge rules used for validation (see note below).
    ///   - constraints: List of constraints that are used for design validation.
    ///
    ///  - SeeAlso: ``ConstraintChecker``, ``EdgeRule``.
    ///
    /// - Important: There must be at least one edge rule per edge type. To allow any edge
    ///   connections, add a rule similar to this example for each edge type:
    ///   ```swift
    ///   EdgeRule(type: MyEdgeType, incoming: .many, outgoing: .many),
    ///   ```
    ///
    /// - Precondition: Traits must have unique name.
    /// - Precondition: Traits used in the object types must exist in the `traits` list and
    ///   must be the same instances as the traits in the list.
    ///
    public init(name: String? = nil,
                version: SemanticVersion? = nil,
                traits: [Trait] = [],
                types: [ObjectType] = [],
                edgeRules: [EdgeRule] = [],
                constraints: [Constraint] = [])
    {
        var seenTraits: [Trait] = []
        var traitNames: Set<String> = Set()

        for trait in traits {
            if let existing = seenTraits.first(where: { $0.name == trait.name }) {
                precondition(existing === trait,
                             "Duplicate traits with name \(trait.name) are different instances")
            }
            else {
                seenTraits.append(trait)
                traitNames.insert(trait.name)
            }
        }

        for type in types {
            for trait in type.traits {
                precondition(traitNames.contains(trait.name),
                             "Missing metamodel trait \(trait.name) for type \(type.name)")
            }
        }
        Self._validateTraitIdentity(knownTraits: traits, types: types)

        self.name = name
        self.version = version
        self.traits = traits
        self.types = types
        self.edgeRules = edgeRules
        self.constraints = constraints
    }
    
    static func _validateTraitIdentity(knownTraits: [Trait], types: [ObjectType]) {
        for type in types {
            for trait in type.traits {
                guard knownTraits.contains(where: { $0 === trait }) else {
                    preconditionFailure("Trait \(trait.name) is of a different identity from known trait with same name")
                }
            }
        }
    }
   
    /// Create a metamodel by merging multiple metamodels.
    ///
    /// - Precondition: Duplicate names are allowed only when the items (traits, object types and
    ///   constraints), are the same instance (when their identity is equal `===`).
    /// - Precondition: Traits used by object types must exist in the list of traits.
    ///
    public init(name: String? = nil, version: SemanticVersion? = nil, merging metamodels: Metamodel ...) {
        var traits: [Trait] = []
        var traitNames: Set<String> = Set()
        var types: [ObjectType] = []
        var constraints: [Constraint] = []
        var edgeRules: [EdgeRule] = []
        
        self.name = name
        self.version = version
        
        for domain in metamodels {
            for trait in domain.traits {
                if let existing = traits.first(where: { $0.name == trait.name }) {
                    precondition(existing === trait,
                                 "Metamodel merge: shared traits with name \(trait.name) are different instances")
                }
                else {
                    traits.append(trait)
                    traitNames.insert(trait.name)
                }
            }

            for type in domain.types {
                if let existing = types.first(where: { $0.name == type.name }) {
                    precondition(existing === type,
                                 "Metamodel merge: shared type with name \(type.name) are different instances")
                }
                else {
                    types.append(type)
                }
            }

            for constraint in domain.constraints {
                if let existing = constraints.first(where: { $0.name == constraint.name }) {
                    precondition(existing === constraint,
                                 "Metamodel merge: shared constraint with name \(constraint.name) are different instances")
                }
                else {
                    constraints.append(constraint)
                }
            }
            // TODO: Make merging of edge rules smarter - avoid duplicates
            edgeRules += domain.edgeRules
        }
        
        for type in types {
            for trait in type.traits {
                precondition(traitNames.contains(trait.name),
                             "Missing metamodel trait \(trait.name) for type \(type.name)")
            }
        }
        Self._validateTraitIdentity(knownTraits: traits, types: types)
        
        self.traits = traits
        self.types = types
        self.constraints = constraints
        self.edgeRules = edgeRules
    }
    
    /// Selection of node object types.
    ///
    public var nodeTypes: [ObjectType] {
        types.filter { $0.topologyType == .node }
    }

    /// Selection of edge object types.
    ///
    public var edgeTypes: [ObjectType] {
        types.filter { $0.topologyType == .edge }
    }

    /// Selection of unstructured object types.
    ///
    public var unstructuredTypes: [ObjectType] {
        types.filter { $0.topologyType == .unstructured }
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
        return types.contains { $0.matches(type)}
    }
    public func trait(name: String) -> Trait? {
        return traits.first { $0.name == name}
    }
}

