//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/06/2022.
//

import PoieticCore

/// Object representing a flow.
///
/// Flow is a node that can be connected to two stocks by a flow edge. One stock
/// is an inflow - stock from which the node drains, and another stock is an
/// outflow - stock to which the node fills.
///
public struct FlowComponent: DefaultValueComponent, PersistableComponent, CustomStringConvertible {
    public var persistableTypeName: String { "Flow" }
    
    /// Default priority – when a priority is not specified, then the priority
    /// is in the order of Flow nodes created.
    ///
    /// This is a convenience feature. User is advised to provide priority
    /// explicitly if a functionality that considers the priority is used.
    ///
    static var defaultPriority = 0
    
    /// Priority specifies an order in which the flow will be considered
    /// when draining a non-negative stocks. The lower the number, the higher
    /// the priority.
    ///
    /// - Note: It is highly recommended to specify priority explicitly if a
    /// functionality that considers the priority is used. It is not advised
    /// to rely on the default priority.
    ///
    public var priority: Int

    public init() {
        FlowComponent.defaultPriority += 1
        self.init(priority: FlowComponent.defaultPriority)
    }
    
    public init(priority: Int) {
        self.priority = priority
    }

    public init(record: ForeignRecord) throws {
        self.priority = try record.intValue(for: "priority")
    }

    public var attributeKeys: [AttributeKey] {
        ["priority"]
    }
    public func attribute(forKey key: AttributeKey) -> (any AttributeValue)? {
        switch key {
        case "priority": return priority
        default: return nil
        }
    }
    
    public var description: String {
        "Flow(priority: \(priority))"
    }

    public mutating func setAttribute(value: any AttributeValue, forKey key: AttributeKey) {
        switch key {
        case "priority": self.priority = value.intValue()!
        default: fatalError("Unknown attribute: \(key) in \(type(of:self))")
        }
    }

}

