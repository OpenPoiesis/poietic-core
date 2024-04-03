//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

/// Set of unique objects that maintains their order.
///
public struct OrderedSet<T: Equatable>: Equatable {
    public typealias Item = T
    public typealias Index = Array<Item>.Index
    var items: [Item]
    
    public init() {
        self.items = []
    }

    public init(_ items: [Item]) {
        self.items = items
    }
    
    public var isEmpty: Bool { items.isEmpty }
    
    public func contains(_ item: Item) -> Bool {
        return items.contains(item)
    }
    
    /// Appends a frame to the frameset.
    ///
    /// The appended frame must not exist in the frameset.
    ///
    public mutating func add(_ item: Item) {
        guard !contains(item) else {
            return
        }
        
        items.append(item)
    }
    
    public mutating func remove(_ id: Item) {
        guard let index = items.firstIndex(of: id) else {
            return
        }
        items.remove(at: index)
    }
}

extension OrderedSet: Collection {
    public subscript(position: Index) -> Item {
        return items[position]
    }

    public var startIndex: Index {
        items.startIndex
    }

    public var endIndex: Index {
        items.endIndex
    }
    public func index(after index: Index) -> Index {
        return items.index(after: index)
    }
}

extension OrderedSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: T...) {
        var result: Array<T> = []
        for item in elements {
            if result.contains(item) {
                continue
            }
            result.append(item)
        }
        self.items = result
    }
    
    public typealias ArrayLiteralElement = T
    
    
}

public typealias ChildrenSet = OrderedSet<ObjectID>
