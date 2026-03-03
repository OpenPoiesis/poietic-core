//
//  Query.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 19/12/2025.
//

/// Query result.
///
/// _Development note:_ It is a wrapped compact map over all world entities.
///
/// - Complexity: O(n). For now.
/// - Note: This is a makeshift world query structure and it is not cheap.
///
public struct QueryResult<T>: Sequence, IteratorProtocol {
    public typealias Element = T
    
    typealias WrappedIterator = [RuntimeID].Iterator
    var wrapped: WrappedIterator
    let predicate: ((RuntimeEntity) -> T?)
    let world: World

    init(world: World, iterator: WrappedIterator? = nil, predicate: @escaping ((RuntimeEntity) -> T?)) {
        self.world = world
        self.wrapped = iterator ?? world.entities.makeIterator()
        self.predicate = predicate
    }
    
    public mutating func next() -> Element? {
        while let value = wrapped.next() {
            let entity = RuntimeEntity(runtimeID: value, world: world)
            if let result = predicate(entity) {
                return result
            }
        }
        return nil
    }
}

