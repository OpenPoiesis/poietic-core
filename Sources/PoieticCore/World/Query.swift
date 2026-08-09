//
//  Query.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 19/12/2025.
//

/// Query result.
///
public struct QueryResult<T>: Sequence {
    private let world: World
    private let ids: [RuntimeID]         // pre-computed matching entity IDs
    private let transform: (World, RuntimeID) -> T?  // transform
    
    init(world: World, ids: some Collection<RuntimeID>, transform: @escaping (World, RuntimeID) -> T?) {
        self.world = world
        self.ids = Array(ids)
        self.transform = transform
    }

    public func makeIterator() -> QueryIterator<T> {
        QueryIterator(world: world, ids: ids, transform: transform)
    }
}

public struct QueryIterator<T>: IteratorProtocol {
    private var wrapped: [RuntimeID].Iterator
    private let world: World
    private let transform: (World, RuntimeID) -> T?
    init(world: World, ids: [RuntimeID], transform: @escaping (World, RuntimeID) -> T?){
        self.world = world
        self.wrapped = ids.makeIterator()
        self.transform = transform
    }
    public mutating func next() -> T? {
        while let id = wrapped.next() {
            if let result = transform(world, id) {
                return result
            }
        }
        return nil
    }
}
