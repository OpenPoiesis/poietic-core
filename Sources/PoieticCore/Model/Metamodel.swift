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
/// - one source of truth
/// - abstraction from persistence, inspection (UI), scripting
/// - transparency and audit-ability of the domain model
/// - reflection
/// - fair compromise between model DSL and native programming language, while
///   providing some possibility of accessing some of the meta-model components
///   through the native programming language identifiers
/// - potentially, in the far future, the metamodel or its parts can be compiled
///   for better performance (which is out of scope at this moment)
///
/// The major use-cases of the reflection:
///
/// - documentation
/// - provide information through tooling to the user about what can be created,
///   used, inspected
/// - there are going to be multiple versions of the toolkit in the wild, users
///   can investigate the capabilities of their installed version of the toolkit
///
/// - Note: Each application is expected to provide their own domain specific metamodel.

public protocol Metamodel: AnyObject {
    /// List of components that are available within the domain described by
    /// this metamodel.
    static var components: [Component.Type] { get }

    /// List of object types allowed in the model.
    ///
    static var objectTypes: [ObjectType] { get }
    
    /// List of built-in variables.
    ///
    static var variables: [BuiltinVariable] { get }
    
    /// List of constraints.
    ///
    /// Constraints are validated before a frame is accepted to the memory.
    /// Memory must not contain stable frames that violate any of the
    /// constraints.
    ///
    static var constraints: [Constraint] { get }
}

extension Metamodel {
    public static func objectType(name: String) -> ObjectType? {
        return objectTypes.first { $0.name == name}
    }
    
    /// Get a component type by name
    public static func inspectableComponent(name: String) -> InspectableComponent.Type? {
        let result = components.compactMap {
            $0 as? InspectableComponent.Type
        }.first {
            $0.componentDescription.name == name
        }
        return result
    }
    
    /// Get a list of built-in variable names.
    ///
    /// This list is created from the ``Metamodel/variables`` list for
    /// convenience.
    ///
    public static var variableNames: [String] {
        variables.map { $0.name }
    }

}

/// A concrete metamodel without any specification.
///
/// Used for testing and playground purposes.
///
/// Each application is expected to provide their own domain specific metamodel.
public class EmptyMetamodel: Metamodel {
    public static var components: [Component.Type] = []
    
    public static var objectTypes: [ObjectType] = []
    
    public static var variables: [BuiltinVariable] = []
    
    public static var constraints: [Constraint] = []
}

/// Metamodel with some basic object types that are typical for multiple
/// kinds of designs.
///
public class BasicMetamodel: Metamodel {
    
    public static let DesignInfo = ObjectType(
        name:"Design",
        structuralType: .unstructured,
        isSystemOwned: true,
        components: [
            DesignInfoComponent.self,
            DocumentationComponent.self,
            AudienceLevelComponent.self,
            KeywordsComponent.self,
        ])

    
    public static var components: [Component.Type] = [
        DesignInfoComponent.self,
        DocumentationComponent.self,
        AudienceLevelComponent.self,
        KeywordsComponent.self,
    ]
    
    public static var objectTypes: [ObjectType] = [
        DesignInfo,
    ]
    
    public static var variables: [BuiltinVariable] = []
    
    public static var constraints: [Constraint] = []

}
