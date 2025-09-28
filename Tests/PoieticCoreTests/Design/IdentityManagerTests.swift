//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 07/05/2025.
//

import Testing

@testable import PoieticCore

struct TestIdentityManager {
    @Test func testContains() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10))
        idman.use(new: ObjectID(20))
        #expect(idman.contains(ObjectID(10).rawValue) == true)
        #expect(idman.isReserved(ObjectID(10)) == true)
        #expect(idman.isUsed(ObjectID(10)) == false)

        #expect(idman.contains(ObjectID(20).rawValue) == true)
        #expect(idman.isReserved(ObjectID(20)) == false)
        #expect(idman.isUsed(ObjectID(20)) == true)

        #expect(idman.contains(ObjectID(30).rawValue) == false)
        #expect(idman.isReserved(ObjectID(30)) == false)
        #expect(idman.isUsed(ObjectID(30)) == false)
    }
    @Test func testType() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10))
        idman.use(new: ObjectSnapshotID(20))
        #expect(idman.type(ObjectID(10).rawValue) == .object)
        #expect(idman.type(ObjectID(20).rawValue) == .objectSnapshot)
    }
    @Test func useRemovesReservation() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10))
        idman.use(reserved: ObjectID(10))
        #expect(idman.isReserved(ObjectID(10)) == false)
        #expect(idman.isUsed(ObjectID(10)) == true)
    }
    @Test func testCreateAndReserve() async throws {
        let idman = IdentityManager()
        let id: ObjectID = idman.reserveNew()
        #expect(idman.isReserved(id) == true)
        #expect(idman.isUsed(id) == false)
    }
    @Test func testCreateAndUse() async throws {
        let idman = IdentityManager()
        let id: ObjectID = idman.createAndUse()
        #expect(idman.isReserved(id) == false)
        #expect(idman.isUsed(id) == true)
    }
    @Test func testReserveIfNeeded() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10))
        idman.use(new: ObjectID(20))
        #expect(idman.reserveIfNeeded(ObjectID(10)) == true)
        #expect(idman.reserveIfNeeded(ObjectSnapshotID(10)) == false)
        #expect(idman.reserveIfNeeded(ObjectID(20)) == true)
        #expect(idman.reserveIfNeeded(ObjectSnapshotID(20)) == false)
    }
}

struct TestIdentityReservation {
    let design: Design
    
    init() {
        self.design = Design()
    }
    @Test func reserveUniqueNew() async throws {
        let context = LoadingContext(design: design)
        let id1: ObjectSnapshotID = try context.reserveUnique(id: nil)
        let id2: ObjectSnapshotID = try context.reserveUnique(id: nil)
        #expect(id1 != id2)
    }
    @Test func reserveUniqueProvided() async throws {
        let context = LoadingContext(design: design)
        let _: ObjectSnapshotID = try context.reserveUnique(id: .int(10))
        #expect(context.contains(ObjectID(10)) == true)
        #expect(context.contains(ObjectID(20)) == false)
        #expect(throws: RawIdentityError.duplicateID(.int(10))) {
            let _: ObjectSnapshotID = try context.reserveUnique(id: .int(10))
        }
        #expect(throws: RawIdentityError.duplicateID(.string("10"))) {
            let _: ObjectSnapshotID = try context.reserveUnique(id: .string("10"))
        }
        #expect(throws: RawIdentityError.duplicateID(.int(10))) {
            let _: ObjectID = try context.reserveUnique(id: .int(10))
        }
    }
    @Test func reserveUniqueProvidedName() async throws {
        let context = LoadingContext(design: design)
        let id: ObjectSnapshotID = try context.reserveUnique(id: .string("thing"))
        #expect(context.contains(id) == true)
        #expect(throws: RawIdentityError.duplicateID(.string("thing"))) {
            let _: ObjectSnapshotID = try context.reserveUnique(id: .string("thing"))
        }
        #expect(throws: RawIdentityError.duplicateID(.id(id.rawValue))) {
            let _: ObjectSnapshotID = try context.reserveUnique(id: .id(id.rawValue))
        }
    }
    @Test func reserveIfNeeded() async throws {
        let context = LoadingContext(design: design)
        let id1: ObjectID = try context.reserveIfNeeded(id: .int(10))
        let id2: ObjectID = try context.reserveIfNeeded(id: .int(10))
        #expect(id1 == id2)
        #expect(context.contains(id1) == true)
    }

    @Test func getActualFromRaw() async throws {
        let context = LoadingContext(design: design)
        design.identityManager.use(new: ObjectID(10))
        #expect(context.getID(.id(10), type: .object) == nil)

        try context.reserveIfNeeded(id: .int(20))
        #expect(context.getID(.int(20), type: .object) == 20)

        let thingID = try context.reserveIfNeeded(id: .string("thing"))
        #expect(context.getID(.string("thing")) == thingID)
        
        let thingID2 = try context.reserveIfNeeded(id: .string("thing"))
        #expect(thingID2 == thingID)
    }
    
    @Test func reserveSnapshot() async throws {
        let context = LoadingContext(design: design)
        try context.reserve(snapshotID: nil, objectID: nil)
        #expect(context.resolvedSnapshots.count == 1)
        try context.reserve(snapshotID: .int(100), objectID: .int(10))
        let last = try #require(context.resolvedSnapshots.last)
        #expect(last.snapshotID == ObjectSnapshotID(100))
        #expect(last.objectID == ObjectID(10))

        try context.reserve(snapshotID: .int(101), objectID: .int(10))
        let last2 = try #require(context.resolvedSnapshots.last)
        #expect(last2.snapshotID == ObjectSnapshotID(101))
        #expect(last2.objectID == ObjectID(10))

        try context.reserve(snapshotID: .int(102), objectID: .string("thing"))
        let last3 = try #require(context.resolvedSnapshots.last)
        #expect(last3.snapshotID == ObjectSnapshotID(102))

        try context.reserve(snapshotID: .int(103), objectID: .string("thing"))
        let last4 = try #require(context.resolvedSnapshots.last)
        #expect(last4.snapshotID == ObjectSnapshotID(103))
        #expect(last4.objectID == last3.objectID)

        #expect(try context.reserveIfNeeded(id: .id(last3.objectID.rawValue)) == last3.objectID)
    }
}
