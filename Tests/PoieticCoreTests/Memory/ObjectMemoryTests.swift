//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import XCTest
@testable import PoieticCore

final class DesignTests: XCTestCase {
    func testEmpty() throws {
        let design = Design()
        
        XCTAssertNil(design.currentFrameID)
        
        let frame = design.deriveFrame()
        
        try design.accept(frame)
        
        XCTAssertFalse(frame.state.isMutable)
        XCTAssertTrue(design.containsFrame(frame.id))
    }
    
    func testSimpleAccept() throws {
        let design = Design()
        
        let frame = design.deriveFrame()
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        
        XCTAssertTrue(frame.contains(a))
        XCTAssertTrue(frame.contains(b))
        XCTAssertTrue(frame.hasChanges)
        XCTAssertEqual(design.versionHistory.count, 0)
        
        try design.accept(frame)
        
        XCTAssertEqual(design.versionHistory, [frame.id])
        XCTAssertEqual(design.currentFrame.id, frame.id)
        XCTAssertTrue(design.currentFrame.contains(a))
        XCTAssertTrue(design.currentFrame.contains(b))
    }
    
    func testMakeObjectFrozenAfterAccept() throws {
        let design = Design()
        let frame = design.deriveFrame()
        let a = frame.create(TestType)
        try design.accept(frame)
        
        let obj = design.currentFrame.object(a)
        XCTAssertEqual(obj.state, VersionState.validated)
    }
    
    func testDiscard() throws {
        let design = Design()
        let frame = design.deriveFrame()
        let _ = frame.create(TestType)
        
        design.discard(frame)
        
        XCTAssertEqual(design.versionHistory.count, 0)
        XCTAssertEqual(frame.state, VersionState.validated)
    }
    
    func testRemoveObject() throws {
        let design = Design()
        let originalFrame = design.deriveFrame()
        
        let a = originalFrame.create(TestType)
        try design.accept(originalFrame)
        
        let originalVersion = design.currentFrameID
        
        let removalFrame = design.deriveFrame()
        XCTAssertTrue(design.currentFrame.contains(a))
        removalFrame.removeCascading(a)
        XCTAssertTrue(removalFrame.hasChanges)
        XCTAssertFalse(removalFrame.contains(a))
        
        try design.accept(removalFrame)
        XCTAssertEqual(design.currentFrame.id, removalFrame.id)
        XCTAssertFalse(design.currentFrame.contains(a))
        
        let original2 = design.frame(originalVersion!)!
        XCTAssertTrue(original2.contains(a))
    }
    
    
    func testUndo() throws {
        let design = Design()
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.deriveFrame()
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.deriveFrame()
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        XCTAssertTrue(design.currentFrame.contains(a))
        XCTAssertTrue(design.currentFrame.contains(b))
        XCTAssertEqual(design.versionHistory, [v0, frame1.id, frame2.id])
        
        design.undo(to: frame1.id)
        
        XCTAssertEqual(design.currentFrameID, frame1.id)
        XCTAssertEqual(design.undoableFrames, [v0])
        XCTAssertEqual(design.redoableFrames, [frame2.id])
        
        design.undo(to: v0)
        
        XCTAssertEqual(design.currentFrameID, v0)
        XCTAssertEqual(design.undoableFrames, [])
        XCTAssertEqual(design.redoableFrames, [frame1.id, frame2.id])
        
        XCTAssertFalse(design.currentFrame.contains(a))
        XCTAssertFalse(design.currentFrame.contains(b))
    }
    
    func testUndoComponent() throws {
        let design = Design()
        
        let frame1 = design.deriveFrame()
        let a = frame1.create(TestType, components: [TestComponent(text: "before")])
        try design.accept(frame1)
        
        let frame2 = design.deriveFrame()
        let obj = frame2.mutableObject(a)
        obj[TestComponent.self] = TestComponent(text: "after")
        
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        let altered = design.currentFrame.object(a)
        XCTAssertEqual(altered[TestComponent.self]!.text, "before")
    }
    func testUndoProperty() throws {
        let design = Design()
        
        let frame1 = design.deriveFrame()
        let a = frame1.create(TestType, attributes: ["text": "before"])
        try design.accept(frame1)
        
        let frame2 = design.deriveFrame()
        let obj = frame2.mutableObject(a)
        obj["text"] = "after"
        
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        let altered = design.currentFrame.object(a)
        XCTAssertEqual(altered["text"], "before")
    }

    func testRedo() throws {
        let design = Design()
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.deriveFrame()
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.deriveFrame()
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        design.redo(to: frame2.id)
        
        XCTAssertTrue(design.currentFrame.contains(a))
        XCTAssertTrue(design.currentFrame.contains(b))
        
        XCTAssertEqual(design.currentFrameID, frame2.id)
        XCTAssertEqual(design.undoableFrames, [v0, frame1.id])
        XCTAssertEqual(design.redoableFrames, [])
        XCTAssertFalse(design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame2.id)
        
        XCTAssertEqual(design.currentFrameID, frame2.id)
        XCTAssertEqual(design.undoableFrames, [v0, frame1.id])
        XCTAssertEqual(design.redoableFrames, [])
        XCTAssertFalse(design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame1.id)
        
        XCTAssertEqual(design.currentFrameID, frame1.id)
        XCTAssertEqual(design.undoableFrames, [v0])
        XCTAssertEqual(design.redoableFrames, [frame2.id])
        XCTAssertTrue(design.canRedo)
        
        XCTAssertTrue(design.currentFrame.contains(a))
        XCTAssertFalse(design.currentFrame.contains(b))
    }
    
    func testRedoReset() throws {
        let design = Design()
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.deriveFrame()
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        design.undo(to: v0)
        
        let frame2 = design.deriveFrame()
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        XCTAssertEqual(design.currentFrameID, frame2.id)
        XCTAssertEqual(design.versionHistory, [v0, frame2.id])
        XCTAssertEqual(design.undoableFrames, [v0])
        XCTAssertEqual(design.redoableFrames, [])
        
        XCTAssertFalse(design.currentFrame.contains(a))
        XCTAssertTrue(design.currentFrame.contains(b))
    }
    
    func testConstraintViolationAccept() throws {
        // TODO: Change this to non-graph constraint check
        let constraint = Constraint(name: "test",
                                    match: AnyPredicate(),
                                    requirement: RejectAll())
       
        let metamodel = Metamodel(constraints: [constraint])
        let design = Design(metamodel: metamodel)
        let frame = design.deriveFrame()
        let a = frame.createNode(TestNodeType)
        let b = frame.createNode(TestNodeType)
        
        // TODO: Test this separately
        XCTAssertThrowsError(try design.accept(frame)) {
            
            guard let error = $0 as? FrameValidationError else {
                XCTFail("Expected FrameValidationError")
                return
            }
            
            XCTAssertEqual(error.violations.count, 1)
            let violation = error.violations[0]
            XCTAssertIdentical(violation.constraint, constraint)
            XCTAssertTrue(violation.objects.contains(a))
            XCTAssertTrue(violation.objects.contains(b))
        }
    }
    
    func testDefaultValueTrait() {
        let design = Design()
        let frame = design.deriveFrame()
        let a = frame.create(TestTypeNoDefault)
        let obj_a = frame[a]
        XCTAssertNil(obj_a["text"])

        let b = frame.create(TestTypeWithDefault)
        let obj_b = frame[b]
        XCTAssertNotNil(obj_b["text"])
        XCTAssertEqual(obj_b["text"], "default")
    }
    func testDefaultValueTraitError() {
        let mem = Design()
        let frame = mem.deriveFrame()
        let a = frame.create(TestTypeNoDefault)
        let _ = frame[a]

        let b = frame.create(TestTypeWithDefault)
        let _ = frame[b]

        XCTAssertThrowsError(try mem.accept(frame)) {
            
            guard let error = $0 as? FrameValidationError else {
                XCTFail("Expected FrameValidationError")
                return
            }
            
            XCTAssertEqual(error.violations.count, 0)
            XCTAssertEqual(error.typeErrors.count, 1)
            if let a_errors = error.typeErrors[a] {
                XCTAssertEqual(a_errors.first, .missingTraitAttribute(TestTraitNoDefault.attributes[0], "Test"))
            }
            else {
                XCTFail("Expected errors for object 'a'")
            }
            XCTAssertNil(error.typeErrors[b])
        }
    }

}
