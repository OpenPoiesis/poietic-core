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
        var idman = NEW_IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(ObjectID(20), type: .object)
        #expect(idman.contains(ObjectID(10)) == true)
        #expect(idman.isReserved(ObjectID(10)) == true)
        #expect(idman.isUsed(ObjectID(10)) == false)

        #expect(idman.contains(ObjectID(20)) == true)
        #expect(idman.isReserved(ObjectID(20)) == false)
        #expect(idman.isUsed(ObjectID(20)) == true)

        #expect(idman.contains(ObjectID(30)) == false)
        #expect(idman.isReserved(ObjectID(30)) == false)
        #expect(idman.isUsed(ObjectID(30)) == false)
    }
    @Test func testType() async throws {
        var idman = NEW_IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(ObjectID(20), type: .snapshot)
        #expect(idman.type(ObjectID(10)) == .object)
        #expect(idman.type(ObjectID(20)) == .snapshot)
    }
    @Test func useRemovesReservation() async throws {
        var idman = NEW_IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(ObjectID(10), type: .object)
        #expect(idman.isReserved(ObjectID(10)) == false)
        #expect(idman.isUsed(ObjectID(10)) == true)
    }
    @Test func useTypeMismatch() async throws {
        var idman = NEW_IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        #expect(idman.use(ObjectID(10), type: .snapshot) == false)
    }
    @Test func useUsedFail() async throws {
        var idman = NEW_IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        #expect(idman.use(ObjectID(10), type: .object) == true)
        #expect(idman.use(ObjectID(10), type: .object) == false)
    }

    @Test func testCreateAndReserve() async throws {
        var idman = NEW_IdentityManager()
        let id = idman.createAndReserve(type: .object)
        #expect(idman.isReserved(id) == true)
        #expect(idman.isUsed(id) == false)
    }
    @Test func testCreateAndUse() async throws {
        var idman = NEW_IdentityManager()
        let id = idman.createAndUse(type: .object)
        #expect(idman.isReserved(id) == false)
        #expect(idman.isUsed(id) == true)
    }
    @Test func testReserveIfNeeded() async throws {
        var idman = NEW_IdentityManager()
        idman.reserve(ObjectID(10), type: .object)
        idman.use(ObjectID(20), type: .object)
        #expect(idman.reserveIfNeeded(ObjectID(10), type: .object) == true)
        #expect(idman.reserveIfNeeded(ObjectID(10), type: .snapshot) == false)
        #expect(idman.reserveIfNeeded(ObjectID(20), type: .object) == true)
        #expect(idman.reserveIfNeeded(ObjectID(20), type: .snapshot) == false)
    }
}

struct TestIdentityReservation {
    let design: Design
    
    init() {
        self.design = Design()
    }
    @Test func reserveUniqueNew() async throws {
        var reservation = IdentityReservation(design: design)
        let id1 = try reservation.reserveUnique(id: nil, type: .snapshot)
        let id2 = try reservation.reserveUnique(id: nil, type: .snapshot)
        #expect(id1 != id2)
    }
    @Test func reserveUniqueProvided() async throws {
        var reservation = IdentityReservation(design: design)
        try reservation.reserveUnique(id: .int(10), type: .snapshot)
        #expect(throws: RawIdentityError.duplicateID(.int(10))) {
            try reservation.reserveUnique(id: .int(10), type: .snapshot)
        }
        #expect(throws: RawIdentityError.duplicateID(.string("10"))) {
            try reservation.reserveUnique(id: .string("10"), type: .snapshot)
        }
        #expect(throws: RawIdentityError.duplicateID(.int(10))) {
            try reservation.reserveUnique(id: .int(10), type: .object)
        }
    }
    @Test func reserveUniqueProvidedName() async throws {
        var reservation = IdentityReservation(design: design)
        let id = try reservation.reserveUnique(id: .string("thing"), type: .snapshot)
        #expect(throws: RawIdentityError.duplicateID(.string("thing"))) {
            try reservation.reserveUnique(id: .string("thing"), type: .snapshot)
        }
        #expect(throws: RawIdentityError.duplicateID(.id(id))) {
            try reservation.reserveUnique(id: .id(id), type: .snapshot)
        }
    }
    @Test func reserveIfNeeded() async throws {
        var reservation = IdentityReservation(design: design)
        let id1 = try reservation.reserveIfNeeded(id: .int(10), type: .snapshot)
        let id2 = try reservation.reserveIfNeeded(id: .int(10), type: .snapshot)
        #expect(id1 == id2)
    }
    @Test func reserveIfNeededTypeMismatch() async throws {
        var reservation = IdentityReservation(design: design)
        try reservation.reserveIfNeeded(id: .int(10), type: .snapshot)
        #expect(throws: RawIdentityError.typeMismatch(.int(10))) {
            try reservation.reserveIfNeeded(id: .int(10), type: .object)
        }
        let id = try reservation.reserveIfNeeded(id: .string("thing"), type: .snapshot)
        #expect(throws: RawIdentityError.typeMismatch(.string("thing"))) {
            try reservation.reserveIfNeeded(id: .string("thing"), type: .object)
        }
        #expect(throws: RawIdentityError.typeMismatch(.id(id))) {
            try reservation.reserveIfNeeded(id: .id(id), type: .object)
        }
    }
    @Test func reserveSnapshot() async throws {
        var reservation = IdentityReservation(design: design)
        try reservation.reserve(snapshotID: nil, objectID: nil)
        #expect(reservation.snapshots.count == 1)
        try reservation.reserve(snapshotID: .int(100), objectID: .int(10))
        let last = try #require(reservation.snapshots.last)
        #expect(last == (ObjectID(100), ObjectID(10)))
        try reservation.reserve(snapshotID: .int(101), objectID: .int(10))
        let last2 = try #require(reservation.snapshots.last)
        #expect(last2 == (ObjectID(101), ObjectID(10)))

        try reservation.reserve(snapshotID: .int(102), objectID: .string("thing"))
        let last3 = try #require(reservation.snapshots.last)
        #expect(last3 == (ObjectID(102), last3.1))
        try reservation.reserve(snapshotID: .int(103), objectID: .string("thing"))
        let last4 = try #require(reservation.snapshots.last)
        #expect(last4 == (ObjectID(103), last3.1))

        #expect(try reservation.reserveIfNeeded(id: .id(last3.1), type: .object) == last3.1)
    }
}
