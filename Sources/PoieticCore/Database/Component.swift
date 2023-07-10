//
//  Component.swift
//  
//
//  Created by Stefan Urbanek on 11/08/2022.
//


/// Protocol for object components.
///
/// Component represents data, a model and is composed of a collection of
/// attributes. An object can have multiple components but only one of each
/// type.
///
/// Important part of the component is its convertibility to a foreign
/// representation for the purpose of interchange between applications or
/// for the purpose of persistence, a storage.
///
/// Typical component holds data provided by the user and everything provided by
/// the user must be available back to the user in an useful and transparent
/// form. The data provided by the user are available through ``Component/foreignRecord()-4l38f``
/// or through the ``Component/attribute(forKey:)``
///
///
///
/// - Note: The ``Component`` is loosely drawing concepts from the Entity
///   Component System model. However in this case, the purpose of the
///   component is firstly data modelling and to provide extensibility of the
///   domain model. Performance is not the primary purpose of this concept in
///   this library.
///
/// - Important: If the component is a part of a model that is being used for
///   a computation or a simulation, then the component-related computation
///   or simulation code should _not_ be part of the component.
///
public protocol Component: MutableKeyedAttributes {
    static var componentDescription: ComponentDescription { get }
    
    /// Create a new component with default component values.
    ///
    /// This is a required method.
    ///
    /// Each component should provide sensible default values for its
    /// attributes. It is highly recommended that the default values are
    /// documented.
    ///
    /// The default values are also used when the component is created
    /// from a foreign record using ``init(record:)`` and when the attribute is
    /// missing in the record.
    ///
    init()
    
    /// Create a component from a foreign record.
    ///
    /// Component is expected to set as many attributes with sensible default
    /// values as possible if the attribute is not provided in the foreign
    /// record.
    ///
    /// Throws an error if the foreign record contains malformed data.
    ///
    /// This is an optional method. Default implementation is provided,
    /// uses the component description to get the relevant attributes from the
    /// foreign record.
    ///
    ///
    /// - Important: Remember that the data in the foreign record might have been
    ///   created by a different version of the application or by a third party
    ///   application. Few rules:
    ///
    ///     - Missing attributes must be assigned sensible default values as
    ///       in the empty initialiser ``init()``.
    ///     - Component should try to read attributes of older version of
    ///       the component type.
    ///     - If semantics of an older attributes has changed, it should be
    ///       converted to the new version if possible.
    ///
    /// - See also: ``Component/attribute(forKey:)``
    ///
    /// - Note: The component should accept older attribute keys, if sensible
    ///   and possible. There is no feedback mechanism yet, but it might be
    ///   likely included in the future.
    ///
    /// - Throws: ``ValueError`` if one of the values provided is of a type that
    ///   can not be converted meaningfully to the corresponding attribute.
    ///   ``AttributeError`` when trying to set an attribute that the component
    ///   does not recognise.
    ///
    ///
    init(record: ForeignRecord) throws
    
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
    /// component's ``componentDescription``.
    ///
    /// - SeeAlso: ``setAttribute(value:forKey:)``, ``init(record:)``
    ///
    func attribute(forKey key: AttributeKey) -> AttributeValue?

    
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
    mutating func setAttribute(value: AttributeValue, forKey key: AttributeKey) throws

    
    /// Create a foreign record from the component.
    ///
    /// Default implementation is provided. The default implementation gets all
    /// the keys from the ``componentDescription`` and retrieves the values
    /// using ``Component/attribute(forKey:)``.
    ///
    /// - SeeAlso: ``attribute(forKey:)``
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
    
    public func foreignRecord() -> ForeignRecord {
        let dict = self.dictionary(withKeys: self.attributeKeys)
        return ForeignRecord(dict)
    }

    // TODO: Do we still need this?
    public var attributeKeys: [String] {
        Self.componentDescription.attributes.map { $0.name }
    }
    
    /// Convenience forwarding for ``ComponentDescription/name``.
    ///
    public var componentName: String {
        Self.componentDescription.name
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
