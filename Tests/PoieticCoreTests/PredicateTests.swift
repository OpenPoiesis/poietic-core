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
        
        empty = ObjectSnapshot(type: TestDomain.Types.TestUnstructured,
                               snapshotID: design.identityManager.reserveNew(type: .objectSnapshot),
                               objectID: design.identityManager.reserveNew(type: .object))
        textObject = ObjectSnapshot(type: TestDomain.Types.DefaultText,
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
        #expect(Predicate.isType(TestDomain.Types.TestUnstructured).match(empty, in: frame))
        #expect(!Predicate.isType(TestDomain.Types.TestEdge).match(empty, in: frame))
    }
    @Test func traitPredicate() throws {
        #expect(Predicate.hasTrait(TestDomain.Traits.DefaultText).match(textObject, in: frame))
        #expect(!Predicate.hasTrait(TestDomain.Traits.NoDefaultText).match(textObject, in: frame))
    }

}
