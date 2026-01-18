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

let TestOrderType = ObjectType(name: "TestOrder",
                          structuralType: .orderedSet,
                          traits: [])


let TestTypeNoDefault = ObjectType(name: "TestNoDefault",
                          structuralType: .unstructured,
                          traits: [TestTraitNoDefault])
let TestTypeWithDefault = ObjectType(name: "TestWithDefault",
                          structuralType: .unstructured,
                          traits: [TestTraitWithDefault])

let TestTraitNoDefault = Trait(
    name: "Test",
    attributes: [
        Attribute("text", type: .string, optional: false)
    ]
)
let TestTraitWithDefault = Trait(
    name: "Test",
    attributes: [
        Attribute("text", type: .string, default: "default", optional: false)
    ]
)


// Test component for RuntimeFrame tests
struct TestComponent: Component, Equatable {
    var text: String

    init(text: String = "__test__") {
        self.text = text
    }
}

let IntegerTrait = Trait(
    name: "Integer",
    attributes: [
        Attribute("value", type: .int, default: 0)
    ]
)

// Test component for RuntimeFrame tests
struct IntegerComponent: Component, Equatable {
    var value: Int

    init(value: Int = 0) {
        self.value = value
    }
}

extension ObjectType {
    static let Unstructured = ObjectType(
        name: "Unstructured",
        structuralType: .unstructured,
        traits: [ IntegerTrait, ]
    )
    
    static let Stock = ObjectType(
        name: "Stock",
        structuralType: .node,
        traits: [ IntegerTrait, ]
    )
    
    static let FlowRate = ObjectType(
        name: "FlowRate",
        structuralType: .node,
        traits: [ IntegerTrait, ]
    )
    
    // Edges
    
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: .edge
    )
    
    static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: .edge
    )
    static let Arrow = ObjectType(
        name: "Arrow",
        structuralType: .edge
    )
    static let IllegalEdge = ObjectType(
        name: "Illegal",
        structuralType: .edge
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
        TestOrderType,

        ObjectType.Unstructured,
        ObjectType.Stock,
        ObjectType.FlowRate,
        ObjectType.Flow,
        ObjectType.Parameter,
        ObjectType.Arrow,
        ObjectType.IllegalEdge,
    ],
    edgeRules: [
        EdgeRule(type: .Arrow),
        EdgeRule(type: TestEdgeType),
        EdgeRule(type: .Flow,
                 origin: IsTypePredicate(.FlowRate),
                 outgoing: .one,
                 target: IsTypePredicate(.Stock)),
        EdgeRule(type: .Flow,
                 origin: IsTypePredicate(.Stock),
                 target: IsTypePredicate(.FlowRate),
                 incoming: .one)
    ]
    
)

extension DesignEntityID: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = UInt64
    public init(integerLiteral value: Self.IntegerLiteralType) {
        self.init(intValue: value)
    }
}
