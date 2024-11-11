//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import XCTest
@testable import PoieticCore

final class DesignTests: XCTestCase {
    var metamodel: Metamodel!
    override func setUp() {
        self.metamodel = TestMetamodel
    }
    func testEmpty() throws {
        let design = Design(metamodel: self.metamodel)
        
        XCTAssertNil(design.currentFrameID)
        
        let frame = design.createFrame()
        
        try design.accept(frame)
        
        XCTAssertEqual(frame.state, .accepted)
        XCTAssertTrue(design.containsFrame(frame.id))
    }
    
    func testSimpleAccept() throws {
        let design = Design(metamodel: self.metamodel)

        let frame = design.createFrame()
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        
        XCTAssertTrue(frame.contains(a))
        XCTAssertTrue(frame.contains(b))
        XCTAssertTrue(frame.hasChanges)
        XCTAssertEqual(design.versionHistory.count, 0)
        
        try design.accept(frame)
        
        XCTAssertEqual(design.versionHistory, [frame.id])
        XCTAssertEqual(design.currentFrame?.id, frame.id)
        XCTAssertTrue(design.currentFrame!.contains(a.id))
        XCTAssertTrue(design.currentFrame!.contains(b.id))
    }
    
    func testDiscard() throws {
        let design = Design()
        let frame = design.createFrame()
        let _ = frame.create(TestType)
        
        design.discard(frame)
        
        XCTAssertEqual(design.versionHistory.count, 0)
        XCTAssertEqual(frame.state, .discarded)
    }
   
    func testRemoveObject() throws {
        let design = Design(metamodel: self.metamodel)
        let originalFrame = design.createFrame()
        
        let a = originalFrame.create(TestType)
        try design.accept(originalFrame)
        
        let originalVersion = design.currentFrameID
        
        let removalFrame = design.createFrame(deriving: design.currentFrame)
        XCTAssertTrue(design.currentFrame!.contains(a.id))
        removalFrame.removeCascading(a.id)
        XCTAssertTrue(removalFrame.hasChanges)
        XCTAssertFalse(removalFrame.contains(a))
        
        try design.accept(removalFrame)
        XCTAssertEqual(design.currentFrame!.id, removalFrame.id)
        XCTAssertFalse(design.currentFrame!.contains(a.id))
        
        let original2 = design.frame(originalVersion!)!
        XCTAssertTrue(original2.contains(a.id))
    }
    
    
    func testUndo() throws {
        let design = Design(metamodel: self.metamodel)
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.createFrame(deriving: design.currentFrame)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        XCTAssertTrue(design.currentFrame!.contains(a.id))
        XCTAssertTrue(design.currentFrame!.contains(b.id))
        XCTAssertEqual(design.versionHistory, [v0, frame1.id, frame2.id])
        
        design.undo(to: frame1.id)
        
        XCTAssertEqual(design.currentFrameID, frame1.id)
        XCTAssertEqual(design.undoableFrames, [v0])
        XCTAssertEqual(design.redoableFrames, [frame2.id])
        
        design.undo(to: v0)
        
        XCTAssertEqual(design.currentFrameID, v0)
        XCTAssertEqual(design.undoableFrames, [])
        XCTAssertEqual(design.redoableFrames, [frame1.id, frame2.id])
        
        XCTAssertFalse(design.currentFrame!.contains(a.id))
        XCTAssertFalse(design.currentFrame!.contains(b.id))
    }
    
    func testUndoComponent() throws {
        let design = Design(metamodel: self.metamodel)

        let frame1 = design.createFrame()
        let a = frame1.create(TestType, components: [TestComponent(text: "before")])
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let obj = frame2.mutate(a.id)
        obj[TestComponent.self] = TestComponent(text: "after")
        
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        let altered = design.currentFrame![a.id]
        XCTAssertEqual(altered[TestComponent.self]!.text, "before")
    }
    func testUndoProperty() throws {
        let design = Design(metamodel: self.metamodel)

        let frame1 = design.createFrame()
        let a = frame1.create(TestType, attributes: ["text": "before"])
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let obj = frame2.mutate(a.id)
        obj["text"] = "after"
        
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        let altered = design.currentFrame![a.id]
        XCTAssertEqual(altered["text"], "before")
    }

    func testRedo() throws {
        let design = Design(metamodel: self.metamodel)
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.createFrame(deriving: design.currentFrame)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        design.redo(to: frame2.id)
        
        XCTAssertTrue(design.currentFrame!.contains(a.id))
        XCTAssertTrue(design.currentFrame!.contains(b.id))
        
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
        
        XCTAssertTrue(design.currentFrame!.contains(a.id))
        XCTAssertFalse(design.currentFrame!.contains(b.id))
    }
    
    func testRedoReset() throws {
        let design = Design(metamodel: self.metamodel)
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.createFrame(deriving: design.currentFrame)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        design.undo(to: v0)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        XCTAssertEqual(design.currentFrameID, frame2.id)
        XCTAssertEqual(design.versionHistory, [v0, frame2.id])
        XCTAssertEqual(design.undoableFrames, [v0])
        XCTAssertEqual(design.redoableFrames, [])
        
        XCTAssertFalse(design.currentFrame!.contains(a.id))
        XCTAssertTrue(design.currentFrame!.contains(b.id))
    }
    
    func testConstraintViolationAccept() throws {
        // TODO: Change this to non-graph constraint check
        let constraint = Constraint(name: "test",
                                    match: AnyPredicate(),
                                    requirement: RejectAll())
       
        let metamodel = Metamodel(constraints: [constraint])
        let design = Design(metamodel: metamodel)
        let frame = design.createFrame()
        let a = frame.createNode(TestNodeType)
        let b = frame.createNode(TestNodeType)
        
        // TODO: Test this separately
        XCTAssertThrowsError(try design.accept(frame)) {
            
            guard let error = $0 as? FrameConstraintError else {
                XCTFail("Expected FrameValidationError")
                return
            }
            
            XCTAssertEqual(error.violations.count, 1)
            let violation = error.violations[0]
            XCTAssertEqual(violation.objects.count, 2)
            XCTAssertTrue(violation.objects.contains(a.id))
            XCTAssertTrue(violation.objects.contains(b.id))
        }
    }
    
    func testDefaultValueTrait() {
        let design = Design()
        let frame = design.createFrame()
        let a = frame.create(TestTypeNoDefault)
        XCTAssertNil(a["text"])

        let b = frame.create(TestTypeWithDefault)
        XCTAssertNotNil(b["text"])
        XCTAssertEqual(b["text"], "default")
    }
    func testDefaultValueTraitError() {
        let design = Design(metamodel: self.metamodel)
        let frame = design.createFrame()
        let a = frame.create(TestTypeNoDefault)
        let b = frame.create(TestTypeWithDefault)

        XCTAssertThrowsError(try design.accept(frame)) {
            
            guard let error = $0 as? FrameConstraintError else {
                XCTFail("Expected FrameValidationError")
                return
            }
            
            XCTAssertEqual(error.violations.count, 0)
            XCTAssertEqual(error.objectErrors.count, 1)
            if let a_errors = error.objectErrors[a.id] {
                XCTAssertEqual(a_errors.first, .missingTraitAttribute(TestTraitNoDefault.attributes[0], "Test"))
            }
            else {
                XCTFail("Expected errors for object 'a'")
            }
            XCTAssertNil(error.objectErrors[b.id])
        }
    }

}
