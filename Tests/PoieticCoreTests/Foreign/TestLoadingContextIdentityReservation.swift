//
//  TestLoadingContextIdentityReservation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 15/10/2025.
//

import Testing
@testable import PoieticCore


struct TestLoadingContextIdentityReservation {
    let design: Design
    let loader: DesignLoader
    let context: LoadingContext
    
    init() {
        self.design = Design()
        self.loader = DesignLoader(metamodel: design.metamodel)
        self.context = LoadingContext(design: design)
    }
    @Test func reserveRequiredConvertible() async throws {
        let foreign: [ForeignEntityID] = [.int(10), .int(20), .int(30)]
        let result = loader.reserveRequired(context, ids: foreign, type: .objectSnapshot)
        #expect(result == nil)
        #expect(design.identityManager.isReserved(ObjectSnapshotID(10)))
        #expect(design.identityManager.isReserved(ObjectSnapshotID(20)))
        #expect(design.identityManager.isReserved(ObjectSnapshotID(30)))
    }

    @Test func reserveRequiredConvertibleDuplicate() async throws {
        design.identityManager.reserve(ObjectSnapshotID(20))
        let foreign: [ForeignEntityID] = [.int(10), .int(20), .int(30)]
        let result = loader.reserveRequired(context, ids: foreign, type: .objectSnapshot)
        #expect(result == 1)
        #expect(design.identityManager.isReserved(ObjectSnapshotID(10)))
        #expect(!design.identityManager.isReserved(ObjectSnapshotID(20)))
        #expect(!design.identityManager.isReserved(ObjectSnapshotID(30)))
    }

    /*
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
     */
}
