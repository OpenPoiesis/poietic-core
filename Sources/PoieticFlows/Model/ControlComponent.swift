//
//  ControlComponent.swift
//  
//
//  Created by Stefan Urbanek on 24/08/2023.
//

import PoieticCore

struct ControlComponent: Component {
    public static var componentDescription = ComponentDescription(
        name: "Control",
        attributes: [
            AttributeDescription(
                name: "value",
                type: .double,
                abstract: "Value of the target node"),
        ]
    )

    public var value: Double

    init() {
        self.value = 0
    }

    func attribute(forKey key: PoieticCore.AttributeKey) -> PoieticCore.AttributeValue? {
        switch key {
        case "value": return ForeignValue(value)
        default: return nil
        }
    }
    
    mutating func setAttribute(value: PoieticCore.AttributeValue, forKey key: PoieticCore.AttributeKey) throws {
        switch key {
        case "value": self.value = try value.doubleValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

struct ChartComponent: Component {
    public static var componentDescription = ComponentDescription(
        name: "Chart",
        attributes: [
//            AttributeDescription(
//                name: "chartType",
//                type: .string,
//                abstract: "Chart type"),
        ]
    )

    public var value: Double

    init() {
        self.value = 0
    }

    func attribute(forKey key: PoieticCore.AttributeKey) -> PoieticCore.AttributeValue? {
        switch key {
        case "value": return ForeignValue(value)
        default: return nil
        }
    }
    
    mutating func setAttribute(value: PoieticCore.AttributeValue, forKey key: PoieticCore.AttributeKey) throws {
        switch key {
        case "value": self.value = try value.doubleValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}
