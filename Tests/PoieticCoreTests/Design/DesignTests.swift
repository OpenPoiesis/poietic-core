//
//  DesignTests.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import Testing
@testable import PoieticCore

@Suite struct DesignTests {
    let metamodel: Metamodel
    let design: Design
    
    init() throws {
        self.metamodel = TestMetamodel
        self.design = Design(metamodel: self.metamodel)
    }
    
    @Test func empty() throws {
        #expect(design.isEmpty)
        #expect(design.currentFrameID == nil)
        #expect(!design.canUndo)
        #expect(!design.canRedo)
        #expect(design.undoableFrames.isEmpty)
        #expect(design.redoableFrames.isEmpty)
    }
    
    @Test func firstAndOnlyFrameNoHistory() throws {
        let frame = design.createFrame()
        
        try design.accept(frame)
        
        #expect(frame.state == .accepted)
        #expect(design.containsFrame(frame.id))
        #expect(design.currentFrameID == frame.id)
        #expect(!design.canUndo)
        #expect(!design.isEmpty)
        #expect(design.undoableFrames.isEmpty)
        #expect(design.redoableFrames.isEmpty)
    }
    
    @Test func simpleAccept() throws {
        let frame = design.createFrame()
        let a = frame.create(TestType)
        let b = frame.create(TestType)

        #expect(design.versionHistory.count == 0)

        try design.accept(frame)
        
        #expect(design.versionHistory == [frame.id])
        #expect(design.currentFrame?.id == frame.id)
        #expect(design.currentFrame!.contains(a.id))
        #expect(design.currentFrame!.contains(b.id))
        
        #expect(design.snapshot(a.snapshotID) != nil)
        #expect(design.snapshot(b.snapshotID) != nil)
    }
    
    @Test func discard() throws {
        let frame = design.createFrame()
        let _ = frame.create(TestType)
        
        design.discard(frame)
        
        #expect(design.versionHistory.isEmpty)
        #expect(frame.state == .discarded)
    }

    @Test func removeFrame() throws {
        let frame = design.createFrame()
        let a = frame.create(TestType)

        try design.accept(frame)
        #expect(design.snapshot(a.snapshotID) != nil)

        design.removeFrame(frame.id)
        #expect(!design.containsFrame(frame.id))
        #expect(design.snapshot(a.snapshotID) == nil)
    }
    
    @Test func removeObject() throws {
        let originalFrame = design.createFrame()
        
        let a = originalFrame.create(TestType)
        try design.accept(originalFrame)
        
        let originalVersion = design.currentFrameID
        
        let removalFrame = design.createFrame(deriving: design.currentFrame)
        #expect(design.currentFrame!.contains(a.id))

        removalFrame.removeCascading(a.id)
        #expect(removalFrame.hasChanges)
        #expect(!removalFrame.contains(a.id))
        
        try design.accept(removalFrame)
        #expect(design.currentFrame!.id == removalFrame.id)
        #expect(!design.currentFrame!.contains(a.id))

        #expect(design.snapshot(a.snapshotID) != nil)

        let original2 = design.frame(originalVersion!)!
        #expect(original2.contains(a.id))
    }
    
    
    @Test func undo() throws {
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.createFrame(deriving: design.currentFrame)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        #expect(design.currentFrame!.contains(a.id))
        #expect(design.currentFrame!.contains(b.id))
        #expect(design.versionHistory == [v0, frame1.id, frame2.id])
        
        design.undo(to: frame1.id)
        
        #expect(design.currentFrameID == frame1.id)
        #expect(design.undoableFrames == [v0])
        #expect(design.redoableFrames == [frame2.id])
        
        design.undo(to: v0)
        
        #expect(design.currentFrameID == v0)
        #expect(design.undoableFrames == [])
        #expect(design.redoableFrames == [frame1.id, frame2.id])
        
        #expect(!design.currentFrame!.contains(a.id))
        #expect(!design.currentFrame!.contains(b.id))
    }
    
    @Test func redo() throws {
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
        
        #expect(design.currentFrame!.contains(a.id))
        #expect(design.currentFrame!.contains(b.id))
        
        #expect(design.currentFrameID == frame2.id)
        #expect(design.undoableFrames == [v0, frame1.id])
        #expect(design.redoableFrames == [])
        #expect(!design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame2.id)
        
        #expect(design.currentFrameID == frame2.id)
        #expect(design.undoableFrames == [v0, frame1.id])
        #expect(design.redoableFrames == [])
        #expect(!design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame1.id)
        
        #expect(design.currentFrameID == frame1.id)
        #expect(design.undoableFrames == [v0])
        #expect(design.redoableFrames == [frame2.id])
        #expect(design.canRedo)
        
        #expect(design.currentFrame!.contains(a.id))
        #expect(!design.currentFrame!.contains(b.id))
    }
   
    @Test func undoRedoNoArgument() throws {
        #expect(!design.canUndo)
        #expect(!design.canRedo)
        #expect(!design.undo())
        #expect(!design.redo())
        try design.accept(design.createFrame())

        // Still can not undo, we have only one frame.
        #expect(!design.canUndo)
        #expect(!design.canRedo)
        #expect(!design.undo())
        #expect(!design.redo())

        try #require(design.currentFrameID != nil)
        
        let originalID = design.currentFrameID!
        let f1 = design.createFrame(deriving: design.currentFrame)
        try design.accept(f1)
        
        #expect(design.canUndo)
        #expect(!design.canRedo)

        #expect(design.undo())
        #expect(!design.undo())

        #expect(design.currentFrameID == originalID)
        
        #expect(!design.canUndo)
        #expect(design.canRedo)

        #expect(design.redo())
        #expect(!design.redo())

        #expect(design.canUndo)
        #expect(!design.canRedo)
    }
    
    @Test func redoReset() throws {
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let discardedFrame = design.createFrame(deriving: design.currentFrame)
        let discardedObject = discardedFrame.create(TestType)
        try design.accept(discardedFrame)
        
        design.undo(to: v0)
        
        let frame2 = design.createFrame(deriving: design.currentFrame)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        #expect(!design.currentFrame!.contains(discardedObject.id))
        #expect(design.currentFrame!.contains(b.id))

        #expect(design.currentFrameID == frame2.id)
        #expect(design.versionHistory == [v0, frame2.id])
        #expect(design.undoableFrames == [v0])
        #expect(design.redoableFrames == [])
        #expect(!design.containsFrame(discardedFrame.id))
        #expect(design.snapshot(discardedObject.snapshotID) == nil)
    }
    
    @Test func constraintViolationAccept() throws {
        let constraint = Constraint(name: "test",
                                    match: AnyPredicate(),
                                    requirement: RejectAll())
        let metamodel = Metamodel(constraints: [constraint])
        let design = Design(metamodel: metamodel)
        
        let frame = design.createFrame()
        let a = frame.createNode(TestNodeType)
        let b = frame.createNode(TestNodeType)
        
        #expect {
            try design.validate(try design.accept(frame))
        } throws: {
            let error = try #require($0 as? FrameValidationError,
                                     "Error is not a FrameConstraintError")
            let violation = try #require(error.violations.first,
                                         "No constraint violation found")

            return error.violations.count == 1
                    && violation.objects.count == 2
                    && violation.objects.contains(a.id)
                    && violation.objects.contains(b.id)
        }
    }

    @Test func removeFrameRemovesFromHistory() throws {
        let frame = design.createFrame()
        try design.accept(frame)
        try design.accept(design.createFrame())
        try design.accept(design.createFrame())
        
        // Sanity first
        #expect(design.undoableFrames.count == 2)
        #expect(design.undoableFrames.contains(frame.id))
        
        design.removeFrame(frame.id)
        #expect(design.undoableFrames.count == 1)
        #expect(!design.undoableFrames.contains(frame.id))
    }
}
