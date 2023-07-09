//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/07/2023.
//

// Basic, reusable components.
public struct NameComponent: Component, CustomStringConvertible {
    
    public static var componentDescription = ComponentDescription(
        name: "Name",
        attributes: [
            AttributeDescription(
                name: "name",
                type: .string,
                abstract: "Node name through which the node is known either in the whole design or a smaller context"),
        ]
    )
    
    /// Name of an object.
    ///
    /// Name is a lose reference to an object. Object name is typically used in a
    /// design by the user, for example in formulas.
    ///
    /// Requirements and rules around object names are model-specific. Some models
    /// might require names to be unique, some might have other ways how to
    /// deal with name duplicity.
    ///
    /// For example in the Stock and Flow model, the name must be unique,
    /// otherwise the model will not compile and therefore can not be used.
    ///
    /// - Note: Regardless of the application, users must be allowed to have
    ///         duplicate names in their models during the design phase.
    ///         An error might be indicated to the user before the compilation,
    ///         if a duplicate name is detected, however the design process
    ///         must not be prevented.
    ///
    public var name: String

    /// Creates a a default expression component.
    ///
    /// The name is set to `unnamed`.
    ///
    public init() {
        self.name = "unnamed"
    }
    
    /// Creates an expression node.
    ///
    public init(name: String) {
        self.name = name
    }
    
    public var description: String {
        return "\(name)"
    }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "name": return ForeignValue(name)
        default: return nil
        }
    }

    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "name": self.name = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

