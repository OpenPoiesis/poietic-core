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
/// This is just an annotation protocol, has no requirements.
///
public protocol Component {
    // Empty, just an annotation.
}

/// Component that is associated with the whole frame, not with particular object.
///
/// This is just an annotation protocol, has no requirements.
///
public protocol FrameComponent: Component {
    // Empty, just an annotation.
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
