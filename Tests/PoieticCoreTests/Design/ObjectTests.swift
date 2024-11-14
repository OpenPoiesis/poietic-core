//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import Testing
@testable import PoieticCore

fileprivate struct CustomNameComponent: Equatable {
    var name: String
    
    init() { self.name = "unnamed" }
    init(name: String) { self.name = name }
    
    public func attribute(forKey key: AttributeKey) -> Variant? {
        switch key {
        case "name": return Variant(name)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: Variant,
                                      forKey key: AttributeKey) throws {
        fatalError("\(#function) is not supposed to be called")
    }
}

fileprivate struct NonStringNameComponent: Equatable {
    var name: Int
    
    init() { self.name = 0 }
    init(name: Int) { self.name = name }
    
    public func attribute(forKey key: AttributeKey) -> Variant? {
        switch key {
        case "name": return Variant(name)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: Variant,
                                      forKey key: AttributeKey) throws {
        fatalError("\(#function) is not supposed to be called")
    }
}



@Suite struct ObjectTests {
    @Test func emtpyName() throws {
        let object = StableObject(id: 1, snapshotID: 1, type: TestType)
        #expect(object.name == nil)
    }
    @Test func nameAttribute() throws {
        let object = StableObject(id: 1, snapshotID: 1, type: TestType,
                                  attributes: ["name": "test"])
        #expect(object.name == "test")
    }

    @Test func nonStringName() throws {
        let object = StableObject(id: 1, snapshotID: 1, type: TestType,
                                  attributes: ["name": 12345])
        #expect(object.name == "12345")
    }

    @Test func invalidNonStringName() throws {
        let object = StableObject(id: 1, snapshotID: 1, type: TestType,
                                  attributes: ["name": 3.14])
        #expect(object.name == nil)
    }

}
