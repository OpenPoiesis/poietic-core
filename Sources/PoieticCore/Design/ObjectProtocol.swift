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

    func attribute(forKey key: String) -> Variant?
}

extension ObjectSnapshot: ObjectProtocol {
    
}

// TODO: This is new, will replace object protocol
public protocol ObjectReference {
    var frame: Frame { get }
    var id: ObjectID { get }
//    var type: ObjectType { get }
//    var name: String? { get }
//    subscript<T>(componentType: T.Type) -> T? where T : Component { get }
//
//    func attribute(forKey key: String) -> Variant?
}

public struct MutableObjectReference {
    public let frame: Frame
    public let id: ObjectID
    
    public init(frame: MutableFrame, id: ObjectID) {
        self.frame = frame
        self.id = id
    }
    
    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return frame[id].components[componentType]
        }
        set(component) {
            frame[id].components[componentType] = component
        }
    }
}

