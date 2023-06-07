//
//  Stock.swift
//  
//
//  Created by Stefan Urbanek on 13/06/2022.
//

// Alias: Accumulator, level, state, container, reservoir, pool

/// A node representing a stock – accumulator, container, reservoir, a pool.
///
public struct StockComponent: DefaultValueComponent, PersistableComponent, CustomStringConvertible {
    public var persistableTypeName: String { "Stock" }

    /// Flag whether the value of the node can be negative.
    var allowsNegative: Bool = false
    
    /// Flag that controls how flow for the stock is being computed when the
    /// stock is non-negative.
    ///
    /// If the stock is non-negative, normally its outflow depends on the
    /// inflow. This is not a problem unless there is a loop of flows between
    /// stocks. In that case, to proceed with computation we need to break the
    /// loop. Stock being with 'delayed inflow' means that the outflow will not
    /// immediately depend on the inflow. The outflow will be computed from
    /// the actual stock value, ignoring the inflow. The inflow will be added
    /// later to the stock.
    ///
    var delayedInflow: Bool = false
    public init() {
        self.init(allowsNegative: false, delayedInflow: false)
    }
    
    public init(allowsNegative: Bool, delayedInflow: Bool) {
        self.allowsNegative = allowsNegative
        self.delayedInflow = delayedInflow
    }
    
    public init(record: ForeignRecord) throws {
        self.allowsNegative = try record.boolValue(for: "allowsNegative")
        self.delayedInflow = try record.boolValue(for: "delayedInflow")
    }

    public var attributeKeys: [AttributeKey] {
        [
            "allowsNegative",
            "delayedInflow"
        ]
    }
    
    public func attribute(forKey key: AttributeKey) -> (any AttributeValue)? {
        switch key {
        case "allowsNegative": return allowsNegative
        case "delayedInflow": return delayedInflow
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: any AttributeValue, forKey key: AttributeKey) {
        switch key {
        case "allowsNegative": self.allowsNegative = value.boolValue()!
        case "delayedInflow": self.delayedInflow = value.boolValue()!
        default: fatalError("Unknown attribute: \(key) in \(type(of:self))")
        }
    }
    
    public var description: String {
        "Stock(allowsNegative: \(allowsNegative) delayedInflow: \(delayedInflow)"
    }

}
