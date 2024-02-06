//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/06/2023.
//

@testable import PoieticCore


let TestType = ObjectType(name: "TestPlain",
                          structuralType: .unstructured,
                          components: [TestComponent.self])
let TestNodeType = ObjectType(name: "TestNode",
                          structuralType: .node,
                          components: [])
let TestEdgeType = ObjectType(name: "TestEdge",
                          structuralType: .edge,
                          components: [])


struct TestComponent: InspectableComponent {
    static var componentSchema = ComponentDescription(
        name: "Test",
        attributes: [
            Attribute(name: "text", type: .string)
        ]
    )
    
    init(text: String) {
        self.text = text
    }
    
    init() {
        text = "__test__"
    }
    
    var componentName: String = "Test"
    
    var text: String
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "text": return ForeignValue(text)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "text": self.text = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

struct IntegerComponent: InspectableComponent, Equatable {
    static var componentSchema = ComponentDescription(
        name: "Integer",
        attributes: [
            Attribute(name: "value", type: .int)
        ]
    )

    var value: Int
    
    init() {
        self.value = 0
    }
    
    init(value: Int) {
        self.value = value
    }
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "value": return ForeignValue(value)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "value": self.value = try value.intValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

extension Metamodel {
    static let Unstructured = ObjectType(
        name: "Unstructured",
        structuralType: .unstructured,
        components: [
            IntegerComponent.self,
        ]
    )
    
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

public let TestMetamodel = Metamodel(
    components: [
        IntegerComponent.self,
    ],
    objectTypes: [
        Metamodel.Unstructured,
        Metamodel.Stock,
        Metamodel.Flow,
        Metamodel.Parameter,
        Metamodel.Arrow,
    ],
    variables: [],
    constraints: []
)
