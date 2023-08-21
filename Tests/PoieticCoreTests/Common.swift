//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/06/2023.
//

@testable import PoieticCore


struct TestComponent: Component {
    static var componentDescription = ComponentDescription(
        name: "Test",
        attributes: [
            AttributeDescription(name: "text", type: .string)
        ]
    )
    
    init(text: String) {
        self.text = text
    }
    
    init() {
        fatalError("Test component cannot be initialized as empty")
    }
    
    var componentName: String = "Test"
    
    var text: String
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "text": return ForeignValue(text)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "text": self.text = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

struct IntegerComponent: Component, Equatable {
    static var componentDescription = ComponentDescription(
        name: "Integer",
        attributes: [
            AttributeDescription(name: "value", type: .int)
        ]
    )

    var value: Int
    
    init() {
        self.value = 0
    }
    
    init(value: Int) {
        self.value = value
    }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "value": return ForeignValue(value)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "value": self.value = try value.intValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

class TestMetamodel: Metamodel {
    static var constraints: [PoieticCore.Constraint] = []
    
    static var objectTypes: [PoieticCore.ObjectType] = [
        Stock,
        Flow,
        Parameter,
        Arrow,
    ]
    
    static var variables: [PoieticCore.BuiltinVariable] = []
    
    static let components: [Component.Type] = [
        IntegerComponent.self,
    ]
    
    static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        components: [
            IntegerComponent.self,
        ]
    )
    
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: .node,
        components: [
            IntegerComponent.self,
        ]
    )
    
    static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: .edge,
        components: [
            // None for now
        ]
    )
    static let Arrow = ObjectType(
        name: "Arrow",
        structuralType: .edge,
        components: [
            // None for now
        ]
    )

}
