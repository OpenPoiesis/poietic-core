//
//  GenerationalArray.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 28/04/2025.
//


/// An indexable collection of elements that tracks validity of indices.
///
public struct GenerationalArray<Element> {
    
    public struct Index: Comparable {
        let position: Int
        let generation: UInt
        
        public static func < (lhs: Index, rhs: Index) -> Bool {
            return lhs.position < rhs.position
        }
        
        public static func == (lhs: Index, rhs: Index) -> Bool {
            return lhs.position == rhs.position && lhs.generation == rhs.generation
        }
    }

    /// Internal storage for elements and their generations
    private var storage: [Element?]
    
    /// Tracks the current generation for each index
    private var generations: [UInt]
    
    /// Queue of reusable indices
    private var freeIndices: [Int]
    
    private var _count: Int = 0
    
    public var isEmpty: Bool { _count == 0 }
    public var count: Int { _count }
    
    /// Creates a new empty generational array
    public init() {
        storage = []
        generations = []
        freeIndices = []
    }
    
    public init<C: Collection>(_ collection: C) where C.Element == Self.Element {
        storage = collection.map { .some($0) }
        generations = Array(repeating: 0, count: storage.count)
        _count = collection.count
        freeIndices = []
    }
    
    /// Appends a new element to the array.
    ///
    /// Parameters:
    ///     - element: The element to append.
    ///
    /// - Returns: An index representing the position and generation.
    @discardableResult
    public mutating func append(_ element: Element) -> Index {
        if let index = freeIndices.popLast() {
            let nextGen = generations[index] + 1
            generations[index] = nextGen
            storage[index] = element
            _count += 1
            return Index(position: index, generation: nextGen)
        } else {
            // Create a new index
            let index = storage.count
            let generation: UInt = 0
            storage.append(element)
            generations.append(generation)
            _count += 1
            return Index(position: index, generation: generation)
        }
    }

    /// Removes an element at the specified index.
    /// - Parameter index: The index to remove
    /// - Returns: Whether the removal was successful
    @discardableResult
    public mutating func remove(at index: Index) -> Bool {
        guard isValid(index) else {
            return false
        }
        
        storage[index.position] = nil
        freeIndices.append(index.position)
        _count -= 1
        return true
    }

    /// Check if an index is valid.
    ///
    /// Index is valid if the storage at given index position is not empty and when the
    /// generation of the index and the stored item matches.
    ///
    /// - Parameters:
    ///     - index: The index to check
    ///
    /// - Returns: Flag whether the index is valid.
    ///
    public func isValid(_ index: Index) -> Bool {
        index.position < storage.count && generations[index.position] == index.generation
    }
}

extension GenerationalArray: Collection {
    
    public var startIndex: Index {
        let position = storage.indices.first { storage[$0] != nil } ?? storage.endIndex
        if position < storage.endIndex {
            return Index(position: position, generation: generations[position])
        }
        else {
            return Index(position: storage.endIndex, generation: 0)
        }
    }
    
    public var endIndex: Index {
        return Index(position: storage.endIndex, generation: UInt.max)
    }
    
    public func index(after i: Index) -> Index {
        var position = i.position + 1
        
        // Find the next non-nil element
        while storage[position] == nil && position < storage.count {
            position += 1
        }
        
        if position < storage.count {
            return Index(position: position, generation: generations[position])
        } else {
            return endIndex
        }
    }
}

// MARK: - MutableCollection Conformance
extension GenerationalArray: MutableCollection {
    public subscript(index: Index) -> Element {
        get {
            guard isValid(index) else { fatalError("Invalid index") }
            return storage[index.position]!
        }
        set {
            guard isValid(index) else { fatalError("Invalid index") }
            storage[index.position] = newValue
        }
    }
}

extension GenerationalArray: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Element
    
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(elements)
    }
}
