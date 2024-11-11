//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import XCTest
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



final class ObjectTests: XCTestCase {
    /// Name should be nil if there is no component with a name.
    func testEmptyName() throws {
        let object = StableObject(id: 1, snapshotID: 1, type: TestType)
        XCTAssertNil(object.name)
    }
    func testNameComponentName() throws {
        let object = StableObject(id: 1,
                                    snapshotID: 1,
                                    type: TestType,
                                    attributes: ["name": "test"])
        XCTAssertEqual(object.name, "test")
    }

    func testNonStringNameComponent() throws {
        let object = StableObject(id: 1,
                                    snapshotID: 1,
                                    type: TestType,
                                    attributes: ["name": 12345])
        XCTAssertEqual(object.name, "12345")
    }

}
