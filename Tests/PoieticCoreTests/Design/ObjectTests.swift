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
        let object = ObjectSnapshot(type: TestType,
                                    snapshotID: ObjectSnapshotID(1),
                                    objectID: ObjectID(1))
        #expect(object.name == nil)
    }
    @Test func nameAttribute() throws {
        let object = ObjectSnapshot(type: TestType,
                                    snapshotID: ObjectSnapshotID(1),
                                    objectID: ObjectID(1),
                                    attributes: ["name": "test"])
        #expect(object.name == "test")
    }

    @Test func nonStringName() throws {
        let object = ObjectSnapshot(type: TestType,
                                    snapshotID: ObjectSnapshotID(1),
                                    objectID: ObjectID(1),
                                    attributes: ["name": 12345])
        #expect(object.name == "12345")
    }

    @Test func invalidNonStringName() throws {
        let object = ObjectSnapshot(type: TestType,
                                    snapshotID: ObjectSnapshotID(1),
                                    objectID: ObjectID(1),
                                    attributes: ["name": 3.14])
        #expect(object.name == nil)
    }

}
