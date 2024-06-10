//
//  Metamodel.swift
//
//
//  Created by Stefan Urbanek on 07/06/2023.
//

/// Object used for validating conformance of a design to a given collection
/// of domains.
///
/// The design can contain only types and traits that are present in the
/// metamodel. The design must comply with all constraints in the
/// metamodel.
///
public class Metamodel {
    private static var _registeredDomainsByName: [String:Domain] = [:]
    // Derived from the above
    private static var _registeredTraitsByName: [String:Trait] = [:]
    private static var _registeredTypesByName: [String:ObjectType] = [:]
    private static var _registeredConstraints: [String:Constraint] = [:]
    
    /// Registers a domain.
    ///
    /// Registers all domains object types, traits and constraints within the
    /// application.
    ///
    /// If the domain contains a type, trait or a constraint with a name that
    /// is already registered, then the new one is ignored, the first one
    /// registered is preserved.
    ///
    /// If you call ``registerDomain(_:)`` multiple times for the same domain,
    /// the additional calls after the first will be ignored.
    ///
    public static func registerDomain(_ domain: Domain) {
        guard Self._registeredDomainsByName[domain.name] == nil else {
            return
        }
        Self._registeredDomainsByName[domain.name] = domain

        for trait in domain.traits {
            guard Self._registeredTraitsByName[trait.name] == nil else {
                continue
            }
            Self._registeredTraitsByName[trait.name] = trait
        }
        for type in domain.objectTypes {
            guard Self._registeredTypesByName[type.name] == nil else {
                continue
            }
            Self._registeredTypesByName[type.name] = type
        }
        for constraint in domain.constraints {
            guard _registeredConstraints[constraint.name] == nil else {
                continue
            }
            _registeredConstraints[constraint.name] = constraint
        }
    }
    
    /// Get a registered domain by its name.
    ///
    public static func registeredDomain(_ name: String) -> Domain? {
        return Self._registeredDomainsByName[name]
    }

    /// Get a registered trait by its name.
    ///
    public static func registeredTrait(_ name: String) -> Trait? {
        return Self._registeredTraitsByName[name]
    }

    /// Get a registered object type by its name.
    ///
    public static func registeredType(_ name: String) -> ObjectType? {
        return Self._registeredTypesByName[name]
    }

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
    
    public init(domains: [Domain] = []) {
        _traits = [:]
        _types = [:]
        constraints = []
        for domain in domains {
            for trait in domain.traits {
                self._traits[trait.name] = trait
            }
            for type in domain.objectTypes {
                self._types[type.name] = type
            }
            for constraint in domain.constraints {
                self.constraints.append(constraint)
            }
        }
    }
    
    public func trait(name: String) -> Trait? {
        return _traits[name]
    }
    
    public func objectType(name: String) -> ObjectType? {
        return _types[name]
    }
}

