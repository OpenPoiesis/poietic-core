//
//  PredicateTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 13/11/2024.
//

import Testing
@testable import PoieticCore

@Suite struct PredicateTest {
    let design: Design
    let frame: DesignPlane
    let empty: ObjectSnapshot
    let textObject: ObjectSnapshot

    init() throws {
        design = Design()
        
        empty = ObjectSnapshot(type: TestType,
                               snapshotID: design.identityManager.reserveNew(type: .objectSnapshot),
                               objectID: design.identityManager.reserveNew(type: .object))
        textObject = ObjectSnapshot(type: TestTypeWithDefault,
                                    snapshotID: design.identityManager.reserveNew(type: .objectSnapshot),
                                    objectID: design.identityManager.reserveNew(type: .object))
        
        frame = DesignPlane(design: design,
                            id: design.identityManager.reserveNew(type: .plane),
                            snapshots: [empty, textObject]
        )
    }

    
    @Test func anyPredicate() throws {
        #expect(Predicate.any.match(empty, in: frame))
    }

    @Test func notPredicate() throws {
        let predicate = Predicate.not(.any)
        #expect(!predicate.match(empty, in: frame))
    }
    @Test func typePredicate() throws {
        #expect(Predicate.isType(TestType).match(empty, in: frame))
        #expect(!Predicate.isType(TestEdgeType).match(empty, in: frame))
    }
    @Test func traitPredicate() throws {
        #expect(Predicate.hasTrait(TestTraitWithDefault).match(textObject, in: frame))
        #expect(!Predicate.hasTrait(TestTraitNoDefault).match(textObject, in: frame))
    }

}
