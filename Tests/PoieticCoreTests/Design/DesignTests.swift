//
//  DesignTests.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import Testing
@testable import PoieticCore

// TODO: Test remove frame removed from undo/redo list

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
        #expect(design.undoList.isEmpty)
        #expect(design.redoList.isEmpty)
    }
    
    @Test func firstAndOnlyFrameNoHistory() throws {
        let frame = design.createFrame()
        
        try design.accept(frame)
        
        #expect(frame.state == .accepted)
        #expect(design.containsFrame(frame.id))
        #expect(design.currentFrameID == frame.id)
        #expect(!design.canUndo)
        #expect(!design.isEmpty)
        #expect(design.undoList.isEmpty)
        #expect(design.redoList.isEmpty)
    }
    
    @Test func simpleAccept() throws {
        let frame = design.createFrame()
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        
        #expect(design.versionHistory.count == 0)
        
        try design.accept(frame)
        
        #expect(design.versionHistory == [frame.id])
        #expect(design.currentFrame?.id == frame.id)
        let currentFrame = try #require(design.currentFrame)
        #expect(currentFrame.contains(a.objectID))
        #expect(currentFrame.contains(b.objectID))
        
        #expect(design.snapshot(a.snapshotID) != nil)
        #expect(design.snapshot(b.snapshotID) != nil)
    }
    @Test func acceptUseReservations() throws {
        let trans = design.createFrame(id: FrameID(1000))
        trans.create(TestType, objectID: ObjectID(10), snapshotID: ObjectSnapshotID(20))
        try design.accept(trans)
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(ObjectSnapshotID(20)))
        #expect(design.identityManager.isUsed(ObjectID(1000)))
        #expect(design.identityManager.used.count == 3)
        #expect(design.identityManager.reserved.count == 0)
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
    @Test func removeFrameReleaseID() throws {
        let trans = design.createFrame(id: FrameID(1000))
        trans.create(TestType, objectID: ObjectID(10), snapshotID: ObjectSnapshotID(20))
        try design.accept(trans)
        #expect(design.identityManager.isUsed(ObjectID(1000)))
        design.removeFrame(FrameID(1000))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(1000)))
    }
    @Test func removeFrameRetainNeededIDs() throws {
        let trans = design.createFrame(id: FrameID(1000))
        trans.create(TestType, objectID: ObjectID(10), snapshotID: ObjectSnapshotID(20))
        let original = try design.accept(trans)
        let trans2 = design.createFrame(deriving: original, id: FrameID(2000))
        let mut = trans2.mutate(ObjectID(10))
        mut["text"] = "text"
        try design.accept(trans2)
        design.removeFrame(FrameID(1000))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(1000)))
        
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(mut.snapshotID))
        #expect(design.identityManager.isUsed(ObjectID(2000)))

        design.removeFrame(FrameID(2000))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(mut.snapshotID))
        #expect(!design.identityManager.isUsed(ObjectID(2000)))
    }

    @Test func removeCurrentFrame() throws {
        let f1 = try design.accept(design.createFrame())
        let f2 = try design.accept(design.createFrame())

        #expect(design.currentFrameID == f2.id)
        #expect(design.undoList == [f1.id])

        design.removeFrame(f2.id)
        #expect(design.currentFrameID == f1.id)
        #expect(design.undoList == [])

        design.removeFrame(f1.id)
        #expect(design.currentFrameID == nil)
    }

    @Test func removeObjectInOrderedSet() throws {
        let originalFrame = design.createFrame()
        
        let a = originalFrame.create(TestType)
        let b = originalFrame.create(TestType)
        let c = originalFrame.create(TestType)
        let order1 = originalFrame.create(TestOrderType,
                                         structure: .orderedSet(a.objectID, []))
        let order2 = originalFrame.create(TestOrderType,
                                          structure: .orderedSet(b.objectID, [c.objectID]))
        try design.accept(originalFrame)
        
        let trans = design.createFrame(deriving: originalFrame)
        
        trans.removeCascading(a.objectID)
        trans.removeCascading(c.objectID)

        let result = try design.accept(trans)

        #expect(!result.contains(a.objectID))
        #expect(!result.contains(order1.objectID))

        #expect(!result.contains(c.objectID))
        #expect(result.contains(b.objectID))
        #expect(result.contains(order2.objectID))

        let obj = try #require(result[order2.objectID])
        guard case let .orderedSet(owner, items) = obj.structure else {
            Issue.record("Structure is not ordered set")
            return
        }
        #expect(owner == b.objectID)
        #expect(items == [])
    }
    
    @Test func removeObject() throws {
        let originalFrame = design.createFrame()
        
        let a = originalFrame.create(TestType)
        try design.accept(originalFrame)
        
        let originalVersion = design.currentFrameID
        
        let removalFrame = design.createFrame(deriving: originalFrame)
        #expect(design.currentFrame!.contains(a.objectID))
        
        removalFrame.removeCascading(a.objectID)
        #expect(removalFrame.hasChanges)
        #expect(!removalFrame.contains(a.objectID))
        
        try design.accept(removalFrame)
        #expect(design.currentFrame!.id == removalFrame.id)
        #expect(!design.currentFrame!.contains(a.objectID))
        
        #expect(design.snapshot(a.snapshotID) != nil)
        
        let original2 = design.frame(originalVersion!)!
        #expect(original2.contains(a.objectID))
    }

    @Test func refCountAndGarbageCollect() throws {
        let trans1 = design.createFrame()
        let a = trans1.create(TestType)
        
        let frame1 = try design.accept(trans1)
        #expect(design.contains(snapshot: a.snapshotID))
        #expect(design.referenceCount(a.snapshotID) == 1)
        
        let trans2 = design.createFrame(deriving: frame1)
        let frame2 = try design.accept(trans2)
        #expect(design.contains(snapshot: a.snapshotID))
        #expect(design.referenceCount(a.snapshotID) == 2)

        design.removeFrame(frame1.id)
        design.removeFrame(frame2.id)
        #expect(!design.contains(snapshot: a.snapshotID))
    }

    @Test func iterateAllDesignSnapshots() throws {
        let trans = design.createFrame()
        let a = trans.create(TestType)
        let b = trans.create(TestType)

        try design.accept(trans)
        #expect(design.contains(snapshot: a.snapshotID))
        #expect(design.contains(snapshot: b.snapshotID))
        
        let snapshots: [ObjectSnapshot] = Array(design.objectSnapshots)
        #expect(snapshots.count == 2)
    }

    @Test func undo() throws {
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.createFrame(deriving: design.currentFrame!)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame!)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        #expect(design.currentFrame!.contains(a.objectID))
        #expect(design.currentFrame!.contains(b.objectID))
        #expect(design.versionHistory == [v0, frame1.id, frame2.id])
        
        design.undo(to: frame1.id)
        
        #expect(design.currentFrameID == frame1.id)
        #expect(design.undoList == [v0])
        #expect(design.redoList == [frame2.id])
        
        design.undo(to: v0)
        
        #expect(design.currentFrameID == v0)
        #expect(design.undoList == [])
        #expect(design.redoList == [frame1.id, frame2.id])
        
        #expect(!design.currentFrame!.contains(a.objectID))
        #expect(!design.currentFrame!.contains(b.objectID))
    }
    
    @Test func redo() throws {
        try design.accept(design.createFrame())
        let v0 = design.currentFrameID!
        
        let frame1 = design.createFrame(deriving: design.currentFrame!)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createFrame(deriving: design.currentFrame!)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        design.redo(to: frame2.id)
        
        #expect(design.currentFrame!.contains(a.objectID))
        #expect(design.currentFrame!.contains(b.objectID))
        
        #expect(design.currentFrameID == frame2.id)
        #expect(design.undoList == [v0, frame1.id])
        #expect(design.redoList == [])
        #expect(!design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame2.id)
        
        #expect(design.currentFrameID == frame2.id)
        #expect(design.undoList == [v0, frame1.id])
        #expect(design.redoList == [])
        #expect(!design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame1.id)
        
        #expect(design.currentFrameID == frame1.id)
        #expect(design.undoList == [v0])
        #expect(design.redoList == [frame2.id])
        #expect(design.canRedo)
        
        #expect(design.currentFrame!.contains(a.objectID))
        #expect(!design.currentFrame!.contains(b.objectID))
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
        let f1 = design.createFrame(deriving: design.currentFrame!)
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
        
        let discardedFrame = design.createFrame(deriving: design.currentFrame!)
        let discardedObject = discardedFrame.create(TestType)
        try design.accept(discardedFrame)
        
        design.undo(to: v0)
        
        let frame2 = design.createFrame(deriving: design.currentFrame!)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        #expect(!design.currentFrame!.contains(discardedObject.objectID))
        #expect(design.currentFrame!.contains(b.objectID))
        
        #expect(design.currentFrameID == frame2.id)
        #expect(design.versionHistory == [v0, frame2.id])
        #expect(design.undoList == [v0])
        #expect(design.redoList == [])
        #expect(!design.containsFrame(discardedFrame.id))
        #expect(design.snapshot(discardedObject.snapshotID) == nil)
    }
    
    @Test func constraintViolationAccept() throws {
        let constraint = Constraint(name: "test",
                                    match: AnyPredicate(),
                                    requirement: RejectAll())
        let metamodel = Metamodel(merging: TestMetamodel,
                                  Metamodel(constraints: [constraint]))
        let design = Design(metamodel: metamodel)
        
        let frame = design.createFrame()
        let a = frame.createNode(TestNodeType)
        let b = frame.createNode(TestNodeType)
        
        #expect {
            try design.accept(frame)
        } throws: {
            let error = try #require($0 as? FrameValidationError,
                                     "Error is not a FrameValidationError")
            guard case .constraintViolation(let violation) = error else {
                return false
            }
            return violation.objects.count == 2
            && violation.objects.contains(a.objectID)
            && violation.objects.contains(b.objectID)
        }
    }
    
    @Test func removeFrameRemovesFromHistory() throws {
        let frame = design.createFrame()
        try design.accept(frame)
        try design.accept(design.createFrame())
        try design.accept(design.createFrame())
        
        // Sanity first
        #expect(design.undoList.count == 2)
        #expect(design.undoList.contains(frame.id))
        
        design.removeFrame(frame.id)
        #expect(design.undoList.count == 1)
        #expect(!design.undoList.contains(frame.id))
    }
    
    @Test func acceptNamedFrame() throws {
        let frame = design.createFrame()
        try design.accept(frame, replacingName: "app")

        #expect(design.containsFrame(frame.id))
        #expect(!design.redoList.contains(frame.id))
        #expect(!design.undoList.contains(frame.id))
        #expect(design.frame(name: "app")?.id == frame.id)
    }
    @Test func acceptAndReplaceNamedFrame() throws {
        let frameOld = design.createFrame()
        try design.accept(frameOld, replacingName: "app")
        let frame = design.createFrame()
        try design.accept(frame, replacingName: "app")

        #expect(!design.containsFrame(frameOld.id))
        #expect(design.containsFrame(frame.id))
        #expect(design.frame(name: "app")?.id == frame.id)
    }
    
    @Test func removeNamedFrame() throws {
        let frame = design.createFrame()
        try design.accept(frame, replacingName: "app")
        design.removeFrame(frame.id)
        
        #expect(design.frame(name: "app")?.id == nil)
    }

}
