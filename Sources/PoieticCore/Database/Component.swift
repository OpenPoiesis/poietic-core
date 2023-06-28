//
//  Component.swift
//  
//
//  Created by Stefan Urbanek on 11/08/2022.
//


/// Protocol for object components.
///
/// Component is a collection of attributes of an object.
///
/// The protocol has no requirements at this moment. It it serves as a marker.
///
public protocol Component: MutableKeyedAttributes {
    static var componentDescription: ComponentDescription { get }
    
    /// Create a new component with default component values.
    ///
    /// This is a required method.
    ///
    init()
    
    /// Create a component from a foreign record.
    ///
    /// Throws an error if the foreign record contains malformed data.
    ///
    /// This is an optional method. Default implementation is provided,
    /// uses the component description to get the relevant attributes from the
    /// foreign record.
    ///
    init(record: ForeignRecord) throws
    
    /// Create a foreign record from the component.
    ///
    /// Default implementation is provided. Uses the component description
    /// to populate the foreign record.
    ///
    func foreignRecord() -> ForeignRecord
}

extension Component {
    public init(record: ForeignRecord) throws {
        self.init()
        for key in record.allKeys {
            let value = record[key]!
            try self.setAttribute(value: value, forKey: key)
        }
    }
    
    public var attributeKeys: [String] {
        Self.componentDescription.attributes.map { $0.name }
    }
    public var componentName: String {
        Self.componentDescription.name
    }
    
    public func foreignRecord() -> ForeignRecord {
        let dict = self.dictionary(withKeys: self.attributeKeys)
        return ForeignRecord(dict)
    }
}

// TODO: REMOVE the following
var _PersistableComponentRegistry: [String:Component.Type] = [:]

/// Register a persistable component by name.
///
/// - SeeAlso: `persistableComponent()`
///
public func registerPersistableComponent(name: String,
                                         type: Component.Type) {
    _PersistableComponentRegistry[name] = type
}
/// Get a class of persistable component by name.
///
/// - SeeAlso: `registerPersistableComponent()`
///
public func persistableComponent(name: String) -> Component.Type? {
    return _PersistableComponentRegistry[name]
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
