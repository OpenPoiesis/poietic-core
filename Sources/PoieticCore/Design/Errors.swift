//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/04/2024.
//

public struct ErrorCollection<T: Error>: Error, Collection {
    public typealias Element = T
    public var errors: [T]

    public func index(after i: Int) -> Int {
        return errors.index(after: i)
    }
    
    public subscript(position: Int) -> T {
        get {
            return errors[position]
        }
    }
    
    public var startIndex: Array<Element>.Index { errors.startIndex}
    public var endIndex: Array<Element>.Index { errors.endIndex }

    public mutating func append(_ error: T) {
        errors.append(error)
    }
    
    public init() {
        self.errors = []
    }
}
