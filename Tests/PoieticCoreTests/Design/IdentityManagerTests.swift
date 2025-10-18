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

