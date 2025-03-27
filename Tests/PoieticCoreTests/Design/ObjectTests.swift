//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import Testing
@testable import PoieticCore

@Suite struct ObjectTests {
    @Test func emtpyName() throws {
        let object = DesignObject(id: ObjectID(1), snapshotID: ObjectID(1), type: TestType)
        #expect(object.name == nil)
    }
    @Test func nameAttribute() throws {
        let object = DesignObject(id: ObjectID(1), snapshotID: ObjectID(1), type: TestType,
                                  attributes: ["name": "test"])
        #expect(object.name == "test")
    }

    @Test func nonStringName() throws {
        let object = DesignObject(id: ObjectID(1), snapshotID: ObjectID(1), type: TestType,
                                  attributes: ["name": 12345])
        #expect(object.name == "12345")
    }

    @Test func invalidNonStringName() throws {
        let object = DesignObject(id: ObjectID(1), snapshotID: ObjectID(1), type: TestType,
                                  attributes: ["name": 3.14])
        #expect(object.name == nil)
    }

}
