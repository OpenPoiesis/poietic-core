//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 31/05/2023.
//

public class ObjectType {
    let name: String
    let structuralType: [ObjectSnapshot.Type]
    let componentTypes: [Component.Type]
    
    init(name: String,
         componentTypes: [Component.Type],
         structuralType: [ObjectSnapshot.Type]) {
        self.name = name
        self.structuralType = structuralType
        self.componentTypes = componentTypes
    }
}
