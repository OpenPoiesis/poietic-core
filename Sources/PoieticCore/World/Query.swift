//
//  Query.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 19/12/2025.
//

public class QueryResult<T> where T: Component {
    public typealias ComponentType = T
    public typealias Element = (RuntimeID, ComponentType)
    public typealias Iterator = [Element].Iterator

    let items: [Element]

    init(_ items: [Element]) {
        self.items = items
    }
    
    /// Get a single element from the result if the result contains only one element. If the result
    /// contains more than one element then `nil` is returned.
    /// 
    public func single() -> Element? {
        guard items.count == 1 else { return nil }
        return items.first
    }
    
    public var count: Int { items.count }
    public var first: Element? { items.first }
    public var isEmpty: Bool { items.isEmpty }

    /// - Complexity: O(n)
    public func contains(_ id: RuntimeID) -> Bool {
        // TODO: Make this O(1)
        return items.contains {$0.0 == id}
    }
}

extension QueryResult: Sequence {
    public func makeIterator() -> Array<Element>.Iterator {
        return items.makeIterator()
    }
}

#if false
public class MultiQueryResult<each T: Component> {
    public typealias Element = (EphemeralID, repeat each T)
    public typealias Iterator = [Element].Iterator

    let items: [Element]

    init(_ items: [Element]) {
        self.items = items
    }
    
    /// Get a single element from the result if the result contains only one element. If the result
    /// contains more than one element then `nil` is returned.
    ///
    public func single() -> Element? {
        guard items.count == 1 else { return nil }
        return items.first
    }
    
    public var count: Int { items.count }
    public var first: Element? { items.first }
    public var isEmpty: Bool { items.isEmpty }

    /// - Complexity: O(n)
    public func contains(_ id: EphemeralID) -> Bool {
        // TODO: Make this O(1)
        return items.contains {$0.0 == id}
    }
}
#endif
