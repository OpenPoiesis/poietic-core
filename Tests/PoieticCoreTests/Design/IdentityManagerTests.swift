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
        idman.reserve(ObjectID(10), type: .object)
        idman.use(new: ObjectID(20), type: .object)
        #expect(idman.contains(ObjectID(10)) == true)
        #expect(idman.isReserved(ObjectID(10), type: .object) == true)
        #expect(idman.isUsed(ObjectID(10)) == false)

        #expect(idman.contains(ObjectID(20)) == true)
        #expect(idman.isReserved(ObjectID(20), type: .object) == false)
        #expect(idman.isUsed(ObjectID(20)) == true)

        #expect(idman.contains(ObjectID(30)) == false)
        #expect(idman.isReserved(ObjectID(30), type: .object) == false)
        #expect(idman.isUsed(ObjectID(30)) == false)
    }
    @Test func testType() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(new: ObjectSnapshotID(20), type: .objectSnapshot)
        #expect(idman.type(ObjectID(10)) == .object)
        #expect(idman.type(ObjectID(20)) == .objectSnapshot)
    }
    @Test func useRemovesReservation() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(reserved: ObjectID(10))
        #expect(idman.isReserved(ObjectID(10), type: .object) == false)
        #expect(idman.isUsed(ObjectID(10)) == true)
    }
    @Test func testCreateAndReserve() async throws {
        let idman = IdentityManager()
        let id: ObjectID = idman.reserveNew(type: .object)
        #expect(idman.isReserved(id, type: .object) == true)
        #expect(idman.isUsed(id) == false)
    }

    @Test func testReserveIfNeeded() async throws {
        let idman = IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(new: ObjectID(20), type: .object)
        #expect(idman.reserveIfNeeded(ObjectID(10), type: .object) == true)
        #expect(idman.reserveIfNeeded(ObjectSnapshotID(10), type: .objectSnapshot) == false)
        #expect(idman.reserveIfNeeded(ObjectID(20), type: .object) == true)
        #expect(idman.reserveIfNeeded(ObjectSnapshotID(20), type: .objectSnapshot) == false)
    }
}

