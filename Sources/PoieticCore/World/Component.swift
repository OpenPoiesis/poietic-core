//
//  Component.swift
//  
//
//  Created by Stefan Urbanek on 11/08/2022.
//

/// Protocol for runtime components of objects.
///
/// Components hold data that are used during runtime. They are typically
/// derived from object attributes.
///
/// Runtime components are not persisted.
///
/// This is just an annotation protocol, has no requirements.
///
public protocol Component {
    associatedtype Storage: ComponentStorageProtocol where Storage.ComponentType == Self
    static func makeStorage() -> any ComponentStorageProtocol
}

extension Component {
    public typealias Storage = DictionaryComponentStorage<Self>
    public static func makeStorage() -> any ComponentStorageProtocol {
        return DictionaryComponentStorage<Self>()
    }

}

/// Component without data.
///
public protocol TagComponent: Component {
    init()
}

extension Component where Self: TagComponent {
    public static func makeStorage() -> any ComponentStorageProtocol {
        return TagComponentStorage<Self>(factory: { Self() })
    }
}

/// Component that can be inspected for debugging.
///
public protocol InspectableComponent {
    // Protocol member names are intentionally longer not to conflict with custom members.
    
    /// List of inspectable attribute names.
    var inspectableAttributes: [String] { get }
    
    /// Get a value for inspectable attribute as variant.
    func inspectableAttribute(_ name: String) -> Variant
}
