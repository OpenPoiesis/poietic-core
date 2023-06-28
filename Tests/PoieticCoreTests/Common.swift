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
    
    init(record: PoieticCore.ForeignRecord) throws {
        fatalError("Test component cannot be created from a foreign record")
    }
    
    init(text: String) {
        self.text = text
    }
    
    init() {
        fatalError("Test component cannot be initialized as empty")
    }
    
    func foreignRecord() -> PoieticCore.ForeignRecord {
        fatalError("Test component cannot be converted to a foreign record")
    }
    
    var componentName: String = "Test"
    
    let text: String
}

struct IntegerComponent: Component, Equatable {
    func foreignRecord() -> PoieticCore.ForeignRecord {
        fatalError("Test Integer component cannot be converted to a foreign record")
    }
    
    static var componentDescription = ComponentDescription(
        name: "Integer",
        attributes: [
            AttributeDescription(name: "value", type: .int)
        ]
    )

    let value: Int
    
    init() {
        self.value = 0
    }
    
    init(value: Int) {
        self.value = value
    }
    
    init(record: PoieticCore.ForeignRecord) throws {
        self.value = try record.intValueIfPresent(for: "value") ?? 0
    }
    
    func asForeignRecord() -> ForeignRecord {
        return ForeignRecord([
            "value": ForeignValue(value)
        ])
    }
}

let TestObjectType = ObjectType(name: "Test",
                                structuralType: Node.self,
                                components: [])

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
        structuralType: Node.self,
        components: [
            .defaultValue(IntegerComponent.self),
        ]
    )
    
    static let Flow = ObjectType(
        name: "Flow",
        structuralType: Node.self,
        components: [
            .defaultValue(IntegerComponent.self),
        ]
    )
    
    static let Parameter = ObjectType(
        name: "Parameter",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )
    static let Arrow = ObjectType(
        name: "Arrow",
        structuralType: Edge.self,
        components: [
            // None for now
        ]
    )

}
