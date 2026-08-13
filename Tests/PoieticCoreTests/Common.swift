//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/06/2023.
//

@testable import PoieticCore


let TestType = ObjectType(name: "TestPlain",
                          topologyType: .unstructured,
                          traits: [])
let TestNodeType = ObjectType(name: "TestNode",
                          topologyType: .node,
                          traits: [])
let TestEdgeType = ObjectType(name: "TestEdge",
                          topologyType: .edge,
                          traits: [])

let TestOrderType = ObjectType(name: "TestOrder",
                          topologyType: .orderedSet,
                          traits: [])


let TestTypeNoDefault = ObjectType(name: "TestNoDefault",
                          topologyType: .unstructured,
                          traits: [TestTraitNoDefault])
let TestTypeWithDefault = ObjectType(name: "TestWithDefault",
                          topologyType: .unstructured,
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
        topologyType: .unstructured,
        traits: [ IntegerTrait, ]
    )
    
    static let Stock = ObjectType(
        name: "Stock",
        topologyType: .node,
        traits: [ IntegerTrait, ]
    )
    
    static let FlowRate = ObjectType(
        name: "FlowRate",
        topologyType: .node,
        traits: [ IntegerTrait, ]
    )
    
    // Edges
    
    static let Flow = ObjectType(
        name: "Flow",
        topologyType: .edge
    )
    
    static let Parameter = ObjectType(
        name: "Parameter",
        topologyType: .edge
    )
    static let Arrow = ObjectType(
        name: "Arrow",
        topologyType: .edge
    )
    static let IllegalEdge = ObjectType(
        name: "Illegal",
        topologyType: .edge
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
                 origin: .isType(.FlowRate),
                 outgoing: .one,
                 target: .isType(.Stock)),
        EdgeRule(type: .Flow,
                 origin: .isType(.Stock),
                 target: .isType(.FlowRate),
                 incoming: .one)
    ]
    
)

extension DesignEntityID: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = UInt64
    public init(integerLiteral value: Self.IntegerLiteralType) {
        self.init(intValue: value)
    }
}
