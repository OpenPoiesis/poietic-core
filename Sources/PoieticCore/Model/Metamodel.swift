//
//  File.swift
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
public protocol Metamodel: AnyObject {
    /// List of components that are available within the domain described by
    /// this metamodel.
    static var components: [Component.Type] { get }
    
    /// List of object types allowed in the model.
    ///
    static var objectTypes: [ObjectType] { get }
    
    static var variables: [BuiltinVariable] { get }
}
