//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 26/06/2023.
//

/// Description of a component.
///
public class ComponentDescription {

    public let name: String
    public let label: String
    
    /// List of attributes of the component.
    ///
    public let attributes: [AttributeDescription]
    
    public let synopsis: String?
    
    /// Create a new component description.
    ///
    public init(name: String,
                label: String? = nil,
                attributes: [AttributeDescription] = [],
                synopsis: String? = nil) {
        self.name = name
        self.label = label ?? name
        self.attributes = attributes
        self.synopsis = synopsis
    }
    
    public var description: String {
        let attrStr = attributes.map { $0.description }
            .joined(separator: ", ")

        return "\(name)(\(attrStr))"
    }
}

/// Description of an attribute.
///
public class AttributeDescription: CustomStringConvertible {
    /// Attribute name – an identifier.
    ///
    public let name: String

    /// Data type of the attribute.
    public let type: ValueType
    
    /// User-oriented label.
    ///
    /// If no label is provided, then the attribute name will be used.
    public let label: String

    /// Short description of the attribute.
    public let synopsis: String?
    
    /// Create a new attribute description.
    ///
    /// - Parameters:
    ///
    ///     - name: Name of the attribute.
    ///     - type: Data type of the attribute.
    ///     - label: User-oriented label of the attribute. If none provided,
    ///         then the attribute name will be used.
    ///     - synopsis: Short description of the attribute, usually displayed as
    ///         a tool-tip.
    ///
    public init(name: String,
                type: ValueType,
                label: String?=nil,
                synopsis: String? = nil) {
        self.name = name
        self.label = label ?? name
        self.synopsis = synopsis
        self.type = type
    }
    
    public var description: String {
        "(\(name) \(type)"
    }
}
