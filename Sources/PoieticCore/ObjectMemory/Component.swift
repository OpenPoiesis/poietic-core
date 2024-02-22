//
//  Component.swift
//  
//
//  Created by Stefan Urbanek on 11/08/2022.
//

// TODO: Add transient (or persistable) component
// TODO: Component hierarchy:
//
// Component
//    +--+----- Inspectable Component
//       +----- Persistable Component (DesignComponent)

/// Protocol for runtime components of objects.
///
/// Components hold data that are used during runtime. They are typically
/// derived from object attributes.
///
/// Runtime components are usually not persisted.
///
/// - Note: When designing a component, design it in a way that all its
///   contents can be reconstructed from other information present in the
///   design.
///
public protocol Component {
}

/// Components that are persisted in the archive. Most of the components
/// are persistable.
///
/// - Note: For now, the persistence is being done using the Swift ``Codable``
///   protocol. This might change in the future.
///
public protocol PersistableComponent: Component, Codable {
    
}

/// Protocol for components where attributes can be inspected by their names.
///
///
/// User data contained in the component is provided to the user's world through
/// public attributes that are advertised through ``componentSchema``.
/// Everything that user enters to the application must be available as public
/// named attributes.
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
///
/// ## Foreign Representation
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
/// The creation of the object should consider that the foreign representation
/// might be of an older or a newer meta-model version, created by some
/// other application version. The component should preserve understanding of
/// historical representations, if possible.
///
///
/// - Note: The ``Component`` is loosely drawing inspiration from the Entity
///   Component System model. However in this case, the purpose of the
///   component is rather data modelling and extensibility of the
///   domain model. More appropriate name would be _Attribute Set_.
///   Performance is not of a concern of this concept in this library.
///
/// - Important: When designing a component and when the component is a part of
///   a model that is being used for a computation or a simulation, then the
///   component-related computation or simulation code should _not_ be part of
///   the component.
///
/// - Remark: _(For library developers)_ The ``Component`` concept was introduced prior to macro system in
///   swift to keep attributes native to the language while still being able
///   to be flexible in modelling and to have richer reflection of the type.
///   In might be replaced by macros in the future, however we are not doing it
///   right now for transparency.
///
/// - Remark: Before converting the component to a macro, consider the following:
///   _How the data, that is "out in the wild", from previous or future
///    meta-model versions are going to be read, transformed and preserved?_
///
public protocol InspectableComponent: Component, MutableKeyedAttributes {
    /// Trait that the component represents.
    ///
    static var trait: Trait { get }
    
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
    /// ## Implementing Initialisation from Foreign Record
    ///
    /// Remember that the data in the foreign record might have been
    /// created by a different version of the application or by a third party
    /// application. Few rules:
    ///
    /// - Missing attributes must be assigned sensible default values as
    ///   in the empty initialiser ``init()``.
    /// - Component should try to read attributes of older version of
    ///   the component type.
    /// - If semantics of an older attributes has changed, it should be
    ///   converted to the new version if possible.
    ///
    /// - See also: ``Component/attribute(forKey:)``
    ///
    /// - Throws: ``ValueError`` if one of the values provided is of a type that
    ///   can not be converted meaningfully to the corresponding attribute.
    ///   ``AttributeError`` when trying to set an attribute that the component
    ///   does not recognise.
    ///
    ///
    init(record: ForeignRecord) throws
    // TODO: Make the above for PersistableComponent only
    
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
    func attribute(forKey key: AttributeKey) -> ForeignValue?

    
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
    mutating func setAttribute(value: ForeignValue, forKey key: AttributeKey) throws
    // TODO: Make the above for PersistableComponent only

    
    /// Create a foreign record from the component.
    ///
    /// Default implementation is provided. The default implementation gets all
    /// the keys from the ``componentSchema`` and retrieves the values
    /// using ``Component/attribute(forKey:)``.
    ///
    /// - SeeAlso: ``attribute(forKey:)``
    ///
    func foreignRecord() -> ForeignRecord
    // TODO: Make the above for PersistableComponent only
}

extension InspectableComponent {
    // FIXME: [REFACTORING] Use this instead of init(record:)
    public init(from object: ObjectSnapshot) throws {
        self.init()
        for attr in Self.trait.attributes {
            guard let value = object[attr.name] ?? attr.defaultValue else {
                fatalError("No default attribute set for attribute \(attr.name) in \(Self.trait.name)")
            }
            try self.setAttribute(value: value, forKey: attr.name)
        }
    }

    /// Default implementation of component initialisation from a foreign record.
    ///
    /// The default implementation gets all the keys from the foreign record and
    /// call ``setAttribute(value:forKey:)`` for the respective values from
    /// the record.
    ///
    /// The default implementation ignores all keys in the foreign record
    /// that are not present in the component description.
    ///
    /// Provide your own implementation that can handle values for keys of
    /// older (or future) versions of foreign representation of the component.
    ///
    public init(record: ForeignRecord) throws {
        self.init()
        for key in record.allKeys {
            guard Self.trait.attributeKeys.contains(key) else {
                continue
            }
            let value = record[key]!
            try self.setAttribute(value: value, forKey: key)
        }
    }
    
    /// Default implementation of getting foreign record from a component.
    ///
    /// The default implementation creates a foreign record based on attribute
    /// keys provided by the component's ``componentSchema``.
    ///
    public func foreignRecord() -> ForeignRecord {
        let dict = self.dictionary(withKeys: Self.trait.attributeKeys)
        return ForeignRecord(dict)
    }

    public var attributeKeys: [String] {
        Self.trait.attributeKeys
    }
    
    /// Convenience forwarding for ``ComponentDescription/name``.
    ///
    public var componentName: String {
        Self.trait.name
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
