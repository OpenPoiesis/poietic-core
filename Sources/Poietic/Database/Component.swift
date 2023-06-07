//
//  Component.swift
//  
//
//  Created by Stefan Urbanek on 11/08/2022.
//

public protocol Component {
}

public protocol PersistableComponent: Component {
    var persistableTypeName: String { get }
    init(record: ForeignRecord) throws
}


/// Protocol for components that can be instantiated without any parameters
/// and will be set-up by component's default values.
///
public protocol DefaultValueComponent: Component {
    init()
}

public struct ComponentSet {
    var components: [Component] = []
    
    public init(_ components: [Component]) {
        self.set(components)
    }
    
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

    public mutating func set(_ components: [Component]) {
        for component in components {
            set(component)
        }
    }
    
    public mutating func removeAll() {
        components.removeAll()
    }
    
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

    public var count: Int { components.count }
    
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
