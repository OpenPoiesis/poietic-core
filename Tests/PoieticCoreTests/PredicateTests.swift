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
    let empty: DesignObject
    let textObject: DesignObject

    init() throws {
        design = Design()
        
        empty = DesignObject(id: design.createID(), snapshotID: design.createID(), type: TestType)
        textObject = DesignObject(id: design.createID(), snapshotID: design.createID(), type: TestTypeWithDefault)
        
        frame = DesignFrame(design: design,
                            id: design.createID(),
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
