//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 31/05/2023.
//

enum ComponentRequirement {
    case required(Component.Type)
    case defaultValue(DefaultValueComponent.Type)
}

public class ObjectType {
    let name: String
    let structuralType: ObjectSnapshot.Type
    let components: [ComponentRequirement]
    
    init(name: String,
         structuralType: ObjectSnapshot.Type,
         components: [ComponentRequirement]) {
        self.name = name
        self.structuralType = structuralType
        self.components = components
    }
    
    var defaultValueComponents: [DefaultValueComponent.Type] {
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
