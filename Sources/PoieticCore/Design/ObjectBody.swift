//
//  ObjectBody.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 19/05/2025.
//

public struct ObjectBody {
    // Identity
    public let id: ObjectID
    public let type: ObjectType
    
    // State
    public var topology: Topology
    public var attributes: [String:Variant]
    
    public subscript(attributeKey: String) -> Variant? {
        attributes[attributeKey]
    }
    
    public init(id: ObjectID,
                type: ObjectType,
                topology: Topology,
                attributes: [String:Variant]) {
        self.id = id
        self.type = type
        self.topology = topology
        self.attributes = attributes
    }
}

