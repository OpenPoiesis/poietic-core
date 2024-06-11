//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 10/06/2024.
//

/// Object describing a design domain.
///
/// The domain is formed by a collection of object types, traits and constraints
/// that together are used to describe a design problem.
///
///  - SeeAlso: ``Design/validate(_:)``, ``Design/accept(_:appendHistory:)``
///
public final class Domain: Sendable {
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
