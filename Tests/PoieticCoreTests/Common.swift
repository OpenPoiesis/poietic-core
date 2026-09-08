//
//  Common.swift
//
//
//  Created by Stefan Urbanek on 19/06/2023.
//

@testable import PoieticCore


enum TestDomain {
    enum Traits {
        static let NoDefaultText = Trait(
            name: "NoDefaultText",
            attributes: [
                Attribute("text", type: .string, optional: false)
            ]
        )
        static let DefaultText = Trait(
            name: "DefaultText",
            attributes: [
                Attribute("text", type: .string, default: "default", optional: false)
            ]
        )
        static let IntegerValue = Trait(
            name: "IntegerValue",
            attributes: [
                Attribute("value", type: .int, default: 0)
            ]
        )

    }
    enum Types {
        // IMPORTANT: When changing the type names here, check with the design loader tests and
        //            update string names in there as well.
        static let TestUnstructured = ObjectType(
            name: "TestUnstructured",
            topologyType: .unstructured,
            traits: []
        )
        static let TestNode = ObjectType(
            name: "TestNode",
            topologyType: .node,
            traits: []
        )
        static let TestEdge = ObjectType(
            name: "TestEdge",
            topologyType: .edge,
            traits: []
        )
        static let TestOrder = ObjectType(
            name: "TestOrder",
            topologyType: .orderedSet,
            traits: []
        )
        static let NoDefaultText = ObjectType(
            name: "NoDefaultText",
            topologyType: .unstructured,
            traits: [Traits.NoDefaultText]
        )
        static let DefaultText = ObjectType(
            name: "DefaultText",
            topologyType: .unstructured,
            traits: [Traits.DefaultText])
        

        /// Node type with the standard ``Trait/Name`` trait.
        static let NamedNode = ObjectType(
            name: "NamedNode",
            topologyType: .node,
            traits: [BasicDomain.Traits.Name]
        )
        static let Unstructured = ObjectType(
            name: "Unstructured",
            topologyType: .unstructured,
            traits: [ Traits.IntegerValue ]
        )
        
        static let Stock = ObjectType(
            name: "Stock",
            topologyType: .node,
            traits: [ Traits.IntegerValue ]
        )
        
        static let FlowRate = ObjectType(
            name: "FlowRate",
            topologyType: .node,
            traits: [ Traits.IntegerValue ]
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
    static let TestMetamodel = Metamodel(
        traits: [
            Traits.NoDefaultText,
            Traits.DefaultText,
            Traits.IntegerValue,
            BasicDomain.Traits.Name,
        ],
        types: [
            Types.TestUnstructured,
            Types.TestNode,
            Types.TestEdge,
            Types.TestOrder,

            Types.NoDefaultText,
            Types.DefaultText,

            Types.NamedNode,

            Types.Unstructured,
            Types.Stock,
            Types.FlowRate,
            Types.Flow,
            Types.Parameter,
            Types.Arrow,
            Types.IllegalEdge,
        ],
        edgeRules: [
            EdgeRule(type: Types.Arrow),
            EdgeRule(type: Types.TestEdge),
            EdgeRule(type: Types.Flow,
                     origin: .isType(Types.FlowRate),
                     outgoing: .one,
                     target: .isType(Types.Stock)),
            EdgeRule(type: Types.Flow,
                     origin: .isType(Types.Stock),
                     target: .isType(Types.FlowRate),
                     incoming: .one)
        ]
        
    )
    static let NameTestMetamodel = Metamodel(
        traits: [BasicDomain.Traits.Name],
        types: [
            Types.NamedNode,
            Types.TestNode,
        ]
    )
}


// Test component for RuntimeFrame tests
struct TestComponent: Component, Equatable {
    var text: String

    init(text: String = "__test__") {
        self.text = text
    }
}

// Test component for RuntimeFrame tests
struct IntegerComponent: Component, Equatable {
    var value: Int

    init(value: Int = 0) {
        self.value = value
    }
}


extension DesignEntityID: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = UInt64
    public init(integerLiteral value: Self.IntegerLiteralType) {
        self.init(intValue: value)
    }
}
