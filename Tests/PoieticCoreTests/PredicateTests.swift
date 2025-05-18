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
    let frame: DesignFrame
    let empty: ObjectSnapshot
    let textObject: ObjectSnapshot

    init() throws {
        design = Design()
        
        empty = ObjectSnapshot(type: TestType,
                               snapshotID: design.identityManager.createAndUse(type: .snapshot),
                               objectID: design.identityManager.createAndUse(type: .object))
        textObject = ObjectSnapshot(type: TestTypeWithDefault,
                                    snapshotID: design.identityManager.createAndUse(type: .object),
                                    objectID: design.identityManager.createAndUse(type: .object))
        
        frame = DesignFrame(design: design,
                            id: design.identityManager.createAndUse(type: .frame),
                            snapshots: [empty, textObject]
        )
    }

    
    @Test func anyPredicate() throws {
        #expect(AnyPredicate().match(empty, in: frame))
    }

    @Test func notPredicate() throws {
        let predicate = NegationPredicate(AnyPredicate())
        #expect(!predicate.match(empty, in: frame))
    }
    @Test func typePredicate() throws {
        #expect(IsTypePredicate(TestType).match(empty, in: frame))
        #expect(!IsTypePredicate(TestEdgeType).match(empty, in: frame))
    }
    @Test func traitPredicate() throws {
        #expect(HasTraitPredicate(TestTraitWithDefault).match(textObject, in: frame))
        #expect(!HasTraitPredicate(TestTraitNoDefault).match(textObject, in: frame))
    }

}
