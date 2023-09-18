//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

// Protocol for wrappers of ObjectSnapshot
//
// - SeeAlso: `Edge`, `Node`
public protocol ObjectProtocol {
    var id: ObjectID { get }
    var type: ObjectType { get }
    var name: String? { get }
    subscript<T>(componentType: T.Type) -> T? where T : Component { get }

    func attribute(forKey key: String) -> ForeignValue?
}

extension ObjectSnapshot: ObjectProtocol {
    
}
