//
//  ObjectBody.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 19/05/2025.
//

import Collections

public struct ObjectBody {
    // Identity
    public let id: ObjectID
    public let type: ObjectType
    
    // State
    public var structure: Structure
    public var parent: ObjectID?
    public var children: OrderedSet<ObjectID>
    public var attributes: [String:Variant]
    
    public subscript(attributeKey: String) -> Variant? {
        attributes[attributeKey]
    }
    
    public init(id: ObjectID,
                type: ObjectType,
                structure: Structure,
                parent: ObjectID?,
                children: [ObjectID],
                attributes: [String:Variant]) {
        self.id = id
        self.type = type
        self.structure = structure
        self.parent = parent
        self.attributes = attributes
        self.children = OrderedSet(children)
    }
    
}

