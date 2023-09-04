//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import XCTest
@testable import PoieticCore

fileprivate struct CustomNameComponent: Component, Equatable {
    static var componentDescription = ComponentDescription(
        name: "CustomName",
        attributes: [
            AttributeDescription(name: "name", type: .string)
        ]
    )

    var name: String
    
    init() { self.name = "unnamed" }
    init(name: String) { self.name = name }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "name": return ForeignValue(name)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        fatalError("\(#function) is not supposed to be called")
    }
}

fileprivate struct NonStringNameComponent: Component, Equatable {
    static var componentDescription = ComponentDescription(
        name: "NonStringName",
        attributes: [
            AttributeDescription(name: "name", type: .int)
        ]
    )

    var name: Int
    
    init() { self.name = 0 }
    init(name: Int) { self.name = name }
    
    public func attribute(forKey key: AttributeKey) -> AttributeValue? {
        switch key {
        case "name": return ForeignValue(name)
        default: return nil
        }
    }
    
    public mutating func setAttribute(value: AttributeValue,
                                      forKey key: AttributeKey) throws {
        fatalError("\(#function) is not supposed to be called")
    }
}



final class ObjectTests: XCTestCase {
    /// Name should be nil if there is no component with a name.
    func testEmptyName() throws {
        let object = ObjectSnapshot(id: 1, snapshotID: 1, type: TestType)
        XCTAssertNil(object.name)
    }
    func testNameComponentName() throws {
        let object = ObjectSnapshot(id: 1,
                                    snapshotID: 1,
                                    type: TestType,
                                    components: [NameComponent(name: "test")])
        XCTAssertEqual(object.name, "test")
    }
    func testCustomNameComponentName() throws {
        let object = ObjectSnapshot(id: 1,
                                    snapshotID: 1,
                                    type: TestType,
                                    components: [CustomNameComponent(name: "test")])
        XCTAssertEqual(object.name, "test")
    }
    func testNonStringNameComponent() throws {
        let object = ObjectSnapshot(id: 1,
                                    snapshotID: 1,
                                    type: TestType,
                                    components: [NonStringNameComponent(name: 12345)])
        XCTAssertEqual(object.name, "12345")
    }

}
