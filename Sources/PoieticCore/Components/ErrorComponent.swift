//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 20/09/2023.
//

/// Component that holds a list of errors related to a node.
///
/// This is a transient component, its content will not be persisted.
///
public struct IssueListComponent: Component {
    public var errors: [Error] = []
    // public var warnings: [???] = []
    
    public static var componentDescription = ComponentDescription(
        name: "IssueList"
    )
    
    public init() {
    }
    
    mutating public func append(_ error: Error) {
        self.errors.append(error)
    }
    
    mutating public func removeAll() {
        self.errors.removeAll()
    }
    
    public func attribute(forKey key: PoieticCore.AttributeKey) -> PoieticCore.AttributeValue? {
        fatalError("Not implemented")
    }
    
    public mutating func setAttribute(value: PoieticCore.AttributeValue, forKey key: PoieticCore.AttributeKey) throws {
        fatalError("Not implemented")
    }
}
