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
/// - Note: When designing a component, design it in a way that all its
///   contents can be reconstructed from other information present in the
///   design.
///
public protocol Component {
}


/// Protocol for components where attributes can be inspected by their names.
///
/// User data contained in the component is provided to the user's world through
/// public attributes that are advertised through ``trait`` that the component
/// adopts.
///
/// Component attributes can be retrieved and set by their name, using ``Component/attribute(forKey:)``
/// and ``Component/setAttribute(value:forKey:)`` respectively. This interface
/// is for unified modification of the component attributes from a foreign
/// source, such as foreign data or a script.
///
/// Component attribute names share the same name-space within an object.
/// There must not be multiple components having an attribute with the same
/// name in an object.
///
public protocol InspectableComponent: Component, MutableKeyedAttributes {
    /// Trait that the component represents.
    ///
    static var trait: Trait { get }
    
    /// Get an attribute value by its name.
    ///
    /// Components should provide values for all user entered attributes so
    /// that they can be used in interchange or persistence. Moreover, the
    /// component must be able to recreate its instance using the
    /// attributes provided through this function.
    ///
    /// Derived attributes do not have to be provided through this interface,
    /// however they might be provided for convenience, debugging or other
    /// inspection purposes.
    ///
    /// Component must provide attributes for all keys advertised through
    /// component's ``componentSchema``.
    ///
    /// - SeeAlso: ``setAttribute(value:forKey:)``, ``init(record:)``
    ///
    func attribute(forKey key: AttributeKey) -> Variant?

    
    /// Set an attribute by its name.
    ///
    /// This function sets an attribute value, typically from a foreign source.
    /// The function should try to convert the value provided
    ///
    /// - Note: The component should accept older attribute keys, if sensible
    ///   and possible. There is no feedback mechanism yet, but it might be
    ///   likely included in the future.
    ///
    /// - Throws: ``ValueError`` if the value provided is of a type that can not
    ///   be converted meaningfully to the attribute. ``AttributeError`` when
    ///   trying to set an attribute that the component does not recognise.
    ///
    /// - SeeAlso: ``attribute(forKey:)``, ``init(record:)``
    ///
    mutating func setAttribute(value: Variant, forKey key: AttributeKey) throws
}

extension InspectableComponent {
    public var attributeKeys: [String] {
        Self.trait.attributeKeys
    }
}

/// Collection of components of an object.
///
/// - Note: This is a naive implementation. Purpose is rather semantic,
///   definitely not optimised for any performance.
///
public struct ComponentSet {
    var components: [Component] = []
    
    /// Create a component set from a list of components.
    ///
    /// If the list of components contains multiple components of the same
    /// type, then the later component in the list will be considered and the
    /// previous one discarded.
    ///
    public init(_ components: [Component]) {
        self.set(components)
    }
    
    /// Sets a component in the component set.
    ///
    /// If a component of the same type as `component` exists, then it is
    /// replaced by the new instance.
    ///
    public mutating func set(_ component: Component) {
        let componentType = type(of: component)
        let index: Int? = components.firstIndex {
            type(of: $0) == componentType
        }
        if let index {
            components[index] = component
        }
        else {
            components.append(component)
        }
    }

    /// Set all components in the provided list.
    ///
    /// If the list of components contains multiple components of the same
    /// type, then the later component in the list will be considered and the
    /// previous one discarded.
    ///
    /// Existing components of the same type will be replaced by the instances
    /// in the list.
    ///
    public mutating func set(_ components: [Component]) {
        for component in components {
            set(component)
        }
    }
    
    /// Removes all components from the set.
    ///
    public mutating func removeAll() {
        components.removeAll()
    }
    
    /// Remove a component of the given type.
    ///
    /// If the component set does not contain a component of the given type
    /// nothing happens.
    ///
    public mutating func remove(_ componentType: Component.Type) {
        components.removeAll {
            type(of: $0) == componentType
        }
    }
    
    public subscript(componentType: Component.Type) -> (Component)? {
        get {
            let first: Component? = components.first {
                type(of: $0) == componentType
            }
            return first
        }
        set(component) {
            let index: Int? = components.firstIndex {
                type(of: $0) == componentType
            }
            if let index {
                if let component {
                    components[index] = component
                }
                else {
                    components.remove(at: index)
                }
            }
            else {
                if let component {
                    components.append(component)
                }
            }

        }
    }
    
    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            for component in components {
                if let component = component as? T {
                    return component
                }
            }
            return nil
        }
        set(component) {
            let index: Int? = components.firstIndex {
                type(of: $0) == componentType
            }
            if let index {
                if let component {
                    components[index] = component
                }
                else {
                    components.remove(at: index)
                }
            }
            else {
                if let component {
                    components.append(component)
                }
            }

        }
    }

    /// Get a count of the components in the set.
    ///
    public var count: Int { components.count }
    
    /// Checks wether the component set contains a component of given type.
    ///
    /// - Returns: `true` if the component set contains a component of given
    ///   type.
    ///
    public func has(_ componentType: Component.Type) -> Bool{
        return components.contains {
            type(of: $0) == componentType
        }
    }
}

extension ComponentSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(elements)
    }
    
    public typealias ArrayLiteralElement = Component
}

extension ComponentSet: Collection {
    public typealias Index = Array<any Component>.Index
    public var startIndex: Index { return components.startIndex }
    public var endIndex: Index { return components.endIndex }
    public func index(after index: Index) -> Index {
        return components.index(after: index)
    }
    public subscript(index: Index) -> any Component {
        return components[index]
    }
}
