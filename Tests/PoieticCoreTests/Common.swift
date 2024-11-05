//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/06/2023.
//

@testable import PoieticCore


let TestType = ObjectType(name: "TestPlain",
                          structuralType: .unstructured,
                          traits: [])
let TestNodeType = ObjectType(name: "TestNode",
                          structuralType: .node,
                          traits: [])
let TestEdgeType = ObjectType(name: "TestEdge",
                          structuralType: .edge,
                          traits: [])

let TestTypeNoDefault = ObjectType(name: "TestNoDefault",
                          structuralType: .unstructured,
                          traits: [TestTraitNoDefault])
let TestTypeWithDefault = ObjectType(name: "TestWithDefault",
                          structuralType: .unstructured,
                          traits: [TestTraitWithDefault])

let TestTrait = Trait(
    name: "Test",
    attributes: [
        Attribute("text", type: .string)
    ]
)
let TestTraitNoDefault = Trait(
    name: "Test",
    attributes: [
        Attribute("text", type: .string)
    ]
)
let TestTraitWithDefault = Trait(
    name: "Test",
    attributes: [
        Attribute("text", type: .string, default: "default")
    ]
)


struct TestComponent:Component {
    init(text: String) {
        self.text = text
    }
    
    init() {
        text = "__test__"
    }
    
    var text: String
    
    public func attribute(forKey key: AttributeKey) -> Variant? {
        switch key {
        case "text": return Variant(text)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: Variant,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "text": self.text = try value.stringValue()
        default:
            fatalError("Unknown attribute")
        }
    }
}

let IntegerTrait = Trait(
    name: "Integer",
    attributes: [
        Attribute("value", type: .int, default: 0)
    ]
)

struct IntegerComponent: Component, Equatable {
    var value: Int
    
    init() {
        self.value = 0
    }
    
    init(value: Int) {
        self.value = value
    }
    
    public func attribute(forKey key: AttributeKey) -> Variant? {
        switch key {
        case "value": return Variant(value)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: Variant,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "value": self.value = try value.intValue()
        default:
            fatalError("Unknown attribute")
        }
    }
}

extension ObjectType {
    static let Unstructured = ObjectType(
        name: "Unstructured",
        structuralType: .unstructured,
        traits: [
            IntegerTrait,
        ]
    )
    
    static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        traits: [
            IntegerTrait,
        ]
    )
    
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: .node,
        traits: [
            IntegerTrait,
        ]
    )
    
    static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: .edge,
        traits: [
            // None for now
        ]
    )
    static let Arrow = ObjectType(
        name: "Arrow",
        structuralType: .edge,
        traits: [
            // None for now
        ]
    )
}

public let TestMetamodel = Metamodel(
    traits: [
        IntegerTrait,
    ],
    types: [
        TestType,
        TestNodeType,
        TestEdgeType,
        TestTypeNoDefault,
        TestTypeWithDefault,

        ObjectType.Unstructured,
        ObjectType.Stock,
        ObjectType.Flow,
        ObjectType.Parameter,
        ObjectType.Arrow,
    ],
    constraints: []
)
