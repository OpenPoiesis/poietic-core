//
//  Metamodel.swift
//
//
//  Created by Stefan Urbanek on 07/06/2023.
//

/// Object describing a model.
///
/// The metamodel is formed by a collection of object types, traits and
/// constraints that together define a domain to which the design conforms.
///
/// The design can contain only types and traits that are present in the
/// metamodel. The design must comply with all constraints in the
/// metamodel.
///
///  - SeeAlso: ``ConstraintChecker``, ``Design/accept(_:appendHistory:)``
///
public final class Metamodel: Sendable {
    /// Name of the metamodel, for debug purposes.
    public let name: String?
    public let version: SemanticVersion?

    /// List of components that are available within the metamodel.
    ///
    public let traits: [Trait]

    /// List of object types allowed in the model.
    ///
    public let types: [ObjectType]
    
    /// List of constraints.
    ///
    /// Constraints are validated before a frame is accepted to the design.
    /// Design must not contain stable frames that violate any of the
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
    ///   - traits: List of traits used or possible in the metamodel.
    ///   - types: List of object types validated by the metamodel.
    ///   - edgeRules: List of edge rules used for validation.
    ///   - constraints: List of constraints that are used for design validation.
    ///
    /// Design is validated according to metamodel with ``Design/validate(_:metamodel:)``.
    ///
    ///  - SeeAlso: ``ConstraintChecker/check(_:)``, ``EdgeRule``.
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
    /// If traits, constraints and types have duplicate name, then the later
    /// will be used.
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
    public func trait(name: String) -> Trait? {
        return traits.first { $0.name == name}
    }
}

