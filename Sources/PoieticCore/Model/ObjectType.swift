//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 31/05/2023.
//

public enum ComponentRequirement {
    case required(Component.Type)
    case defaultValue(Component.Type)
}

public class ObjectType {
    public let name: String
    public let structuralType: ObjectSnapshot.Type
    public let components: [ComponentRequirement]
    
    public init(name: String,
         structuralType: ObjectSnapshot.Type,
         components: [ComponentRequirement]) {
        self.name = name
        self.structuralType = structuralType
        self.components = components
    }
    
    public var defaultValueComponents: [Component.Type] {
        let components = self.components.compactMap {
            if case let .defaultValue(component) = $0 {
                return component
            }
            else {
                return nil
            }
        }
        return components
    }
}
