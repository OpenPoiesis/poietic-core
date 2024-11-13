//
//  PredicateTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 13/11/2024.
//

import XCTest
@testable import PoieticCore

final class TestPredicates : XCTestCase {
    var design: Design!
    var frame: StableFrame!
    var empty: StableObject!
    var textObject: StableObject!
    
    override func setUp() {
        design = Design()
        empty = StableObject(id: design.allocateID(),
                              snapshotID: design.allocateID(),
                              type: TestType)
        textObject = StableObject(id: design.allocateID(),
                              snapshotID: design.allocateID(),
                              type: TestTypeWithDefault)
        frame = StableFrame(design: design,
                            id: design.allocateID(),
                            snapshots: [empty, textObject]
        )
    }
    func testAnyPredicate() throws {
        let predicate = AnyPredicate()
        XCTAssertTrue(predicate.match(empty, in: frame))
    }
    func testNotPredicate() throws {
        let predicate = NegationPredicate(AnyPredicate())
        XCTAssertFalse(predicate.match(empty, in: frame))
    }
    func testTypePredicate() throws {
        XCTAssertTrue(IsTypePredicate(TestType).match(empty, in: frame))
        XCTAssertFalse(IsTypePredicate(TestEdgeType).match(empty, in: frame))
    }
    func testTraitPredicate() throws {
        XCTAssertTrue(HasTraitPredicate(TestTraitWithDefault).match(textObject, in: frame))
        XCTAssertFalse(HasTraitPredicate(TestTraitNoDefault).match(textObject, in: frame))
    }
}

