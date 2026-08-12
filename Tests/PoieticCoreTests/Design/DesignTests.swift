//
//  DesignTests.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import Testing
@testable import PoieticCore

// TODO: Test remove plane removed from undo/redo list

@Suite struct DesignTests {
    let metamodel: Metamodel
    let design: Design
    
    init() throws {
        self.metamodel = TestMetamodel
        self.design = Design(metamodel: self.metamodel)
    }
    
    @Test func empty() throws {
        #expect(design.isEmpty)
        #expect(design.currentPlaneID == nil)
        #expect(!design.canUndo)
        #expect(!design.canRedo)
        #expect(design.undoList.isEmpty)
        #expect(design.redoList.isEmpty)
    }
    
    @Test func firstAndOnlyFrameNoHistory() throws {
        let frame = design.createPlane()
        
        try design.accept(frame)
        
        #expect(frame.state == .accepted)
        #expect(design.containsPlane(frame.id))
        #expect(design.currentPlaneID == frame.id)
        #expect(!design.canUndo)
        #expect(!design.isEmpty)
        #expect(design.undoList.isEmpty)
        #expect(design.redoList.isEmpty)
    }
    
    @Test func simpleAccept() throws {
        let frame = design.createPlane()
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        
        #expect(design.versionHistory.count == 0)
        
        try design.accept(frame)
        
        #expect(design.versionHistory == [frame.id])
        #expect(design.currentPlane?.id == frame.id)
        let currentFrame = try #require(design.currentPlane)
        #expect(currentFrame.contains(a.objectID))
        #expect(currentFrame.contains(b.objectID))
        
        #expect(design.snapshot(a.snapshotID) != nil)
        #expect(design.snapshot(b.snapshotID) != nil)
    }
    @Test func acceptUseReservations() throws {
        let trans = design.createPlane(id: PlaneID(1000))
        trans.create(TestType, objectID: ObjectID(10), snapshotID: ObjectSnapshotID(20))
        try design.accept(trans)
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(ObjectSnapshotID(20)))
        #expect(design.identityManager.isUsed(ObjectID(1000)))
        #expect(design.identityManager.used.count == 3)
        #expect(design.identityManager.reserved.count == 0)
    }
    @Test func discard() throws {
        let frame = design.createPlane()
        let _ = frame.create(TestType)
        
        design.discard(frame)
        
        #expect(design.versionHistory.isEmpty)
        #expect(frame.state == .discarded)
    }
    
    @Test func removeFrame() throws {
        let frame = design.createPlane()
        let a = frame.create(TestType)
        
        try design.accept(frame)
        #expect(design.snapshot(a.snapshotID) != nil)
        
        design.removePlane(frame.id)
        #expect(!design.containsPlane(frame.id))
        #expect(design.snapshot(a.snapshotID) == nil)
    }
    @Test func removeFrameReleaseID() throws {
        let trans = design.createPlane(id: PlaneID(1000))
        trans.create(TestType, objectID: ObjectID(10), snapshotID: ObjectSnapshotID(20))
        try design.accept(trans)
        #expect(design.identityManager.isUsed(ObjectID(1000)))
        design.removePlane(PlaneID(1000))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(1000)))
    }
    @Test func removeFrameRetainNeededIDs() throws {
        let trans = design.createPlane(id: PlaneID(1000))
        trans.create(TestType, objectID: ObjectID(10), snapshotID: ObjectSnapshotID(20))
        let original = try design.accept(trans)
        let trans2 = design.createPlane(deriving: original, id: PlaneID(2000))
        let mut = trans2.mutate(ObjectID(10))
        mut["text"] = "text"
        try design.accept(trans2)
        design.removePlane(PlaneID(1000))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(1000)))
        
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(mut.snapshotID))
        #expect(design.identityManager.isUsed(ObjectID(2000)))

        design.removePlane(PlaneID(2000))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(mut.snapshotID))
        #expect(!design.identityManager.isUsed(ObjectID(2000)))
    }

    @Test func removeCurrentFrame() throws {
        let f1 = try design.accept(design.createPlane())
        let f2 = try design.accept(design.createPlane())

        #expect(design.currentPlaneID == f2.id)
        #expect(design.undoList == [f1.id])

        design.removePlane(f2.id)
        #expect(design.currentPlaneID == f1.id)
        #expect(design.undoList == [])

        design.removePlane(f1.id)
        #expect(design.currentPlaneID == nil)
    }

    @Test func removeObjectInOrderedSet() throws {
        let originalFrame = design.createPlane()
        
        let a = originalFrame.create(TestType)
        let b = originalFrame.create(TestType)
        let c = originalFrame.create(TestType)
        let order1 = originalFrame.create(TestOrderType,
                                         structure: .orderedSet(a.objectID, []))
        let order2 = originalFrame.create(TestOrderType,
                                          structure: .orderedSet(b.objectID, [c.objectID]))
        try design.accept(originalFrame)
        
        let trans = design.createPlane(deriving: originalFrame)
        
        trans.removeCascading(a.objectID)
        trans.removeCascading(c.objectID)

        let result = try design.accept(trans)

        #expect(!result.contains(a.objectID))
        #expect(!result.contains(order1.objectID))

        #expect(!result.contains(c.objectID))
        #expect(result.contains(b.objectID))
        #expect(result.contains(order2.objectID))

        let obj = try #require(result[order2.objectID])
        guard case let .orderedSet(owner, items) = obj.topology else {
            Issue.record("Topology is not ordered set")
            return
        }
        #expect(owner == b.objectID)
        #expect(items == [])
    }
    
    @Test func removeObject() throws {
        let originalFrame = design.createPlane()
        
        let a = originalFrame.create(TestType)
        try design.accept(originalFrame)
        
        let originalVersion = design.currentPlaneID
        
        let removalFrame = design.createPlane(deriving: originalFrame)
        #expect(design.currentPlane!.contains(a.objectID))
        
        removalFrame.removeCascading(a.objectID)
        #expect(removalFrame.hasChanges)
        #expect(!removalFrame.contains(a.objectID))
        
        try design.accept(removalFrame)
        #expect(design.currentPlane!.id == removalFrame.id)
        #expect(!design.currentPlane!.contains(a.objectID))
        
        #expect(design.snapshot(a.snapshotID) != nil)
        
        let original2 = design.plane(originalVersion!)!
        #expect(original2.contains(a.objectID))
    }

    @Test func refCountAndGarbageCollect() throws {
        let trans1 = design.createPlane()
        let a = trans1.create(TestType)
        
        let frame1 = try design.accept(trans1)
        #expect(design.contains(snapshot: a.snapshotID))
        #expect(design.referenceCount(a.snapshotID) == 1)
        
        let trans2 = design.createPlane(deriving: frame1)
        let frame2 = try design.accept(trans2)
        #expect(design.contains(snapshot: a.snapshotID))
        #expect(design.referenceCount(a.snapshotID) == 2)

        design.removePlane(frame1.id)
        design.removePlane(frame2.id)
        #expect(!design.contains(snapshot: a.snapshotID))
    }

    @Test func iterateAllDesignSnapshots() throws {
        let trans = design.createPlane()
        let a = trans.create(TestType)
        let b = trans.create(TestType)

        try design.accept(trans)
        #expect(design.contains(snapshot: a.snapshotID))
        #expect(design.contains(snapshot: b.snapshotID))
        
        let snapshots: [ObjectSnapshot] = Array(design.objectSnapshots)
        #expect(snapshots.count == 2)
    }

    @Test func undo() throws {
        try design.accept(design.createPlane())
        let v0 = design.currentPlaneID!
        
        let frame1 = design.createPlane(deriving: design.currentPlane!)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createPlane(deriving: design.currentPlane!)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        #expect(design.currentPlane!.contains(a.objectID))
        #expect(design.currentPlane!.contains(b.objectID))
        #expect(design.versionHistory == [v0, frame1.id, frame2.id])
        
        design.undo(to: frame1.id)
        
        #expect(design.currentPlaneID == frame1.id)
        #expect(design.undoList == [v0])
        #expect(design.redoList == [frame2.id])
        
        design.undo(to: v0)
        
        #expect(design.currentPlaneID == v0)
        #expect(design.undoList == [])
        #expect(design.redoList == [frame1.id, frame2.id])
        
        #expect(!design.currentPlane!.contains(a.objectID))
        #expect(!design.currentPlane!.contains(b.objectID))
    }
    
    @Test func redo() throws {
        try design.accept(design.createPlane())
        let v0 = design.currentPlaneID!
        
        let frame1 = design.createPlane(deriving: design.currentPlane!)
        let a = frame1.create(TestType)
        try design.accept(frame1)
        
        let frame2 = design.createPlane(deriving: design.currentPlane!)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        design.undo(to: frame1.id)
        design.redo(to: frame2.id)
        
        #expect(design.currentPlane!.contains(a.objectID))
        #expect(design.currentPlane!.contains(b.objectID))
        
        #expect(design.currentPlaneID == frame2.id)
        #expect(design.undoList == [v0, frame1.id])
        #expect(design.redoList == [])
        #expect(!design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame2.id)
        
        #expect(design.currentPlaneID == frame2.id)
        #expect(design.undoList == [v0, frame1.id])
        #expect(design.redoList == [])
        #expect(!design.canRedo)
        
        design.undo(to: v0)
        design.redo(to: frame1.id)
        
        #expect(design.currentPlaneID == frame1.id)
        #expect(design.undoList == [v0])
        #expect(design.redoList == [frame2.id])
        #expect(design.canRedo)
        
        #expect(design.currentPlane!.contains(a.objectID))
        #expect(!design.currentPlane!.contains(b.objectID))
    }
    
    @Test func undoRedoNoArgument() throws {
        #expect(!design.canUndo)
        #expect(!design.canRedo)
        #expect(!design.undo())
        #expect(!design.redo())
        try design.accept(design.createPlane())
        
        // Still can not undo, we have only one plane.
        #expect(!design.canUndo)
        #expect(!design.canRedo)
        #expect(!design.undo())
        #expect(!design.redo())
        
        try #require(design.currentPlaneID != nil)
        
        let originalID = design.currentPlaneID!
        let f1 = design.createPlane(deriving: design.currentPlane!)
        try design.accept(f1)
        
        #expect(design.canUndo)
        #expect(!design.canRedo)
        
        #expect(design.undo())
        #expect(!design.undo())
        
        #expect(design.currentPlaneID == originalID)
        
        #expect(!design.canUndo)
        #expect(design.canRedo)
        
        #expect(design.redo())
        #expect(!design.redo())
        
        #expect(design.canUndo)
        #expect(!design.canRedo)
    }
    
    @Test func redoReset() throws {
        try design.accept(design.createPlane())
        let v0 = design.currentPlaneID!
        
        let discardedFrame = design.createPlane(deriving: design.currentPlane!)
        let discardedObject = discardedFrame.create(TestType)
        try design.accept(discardedFrame)
        
        design.undo(to: v0)
        
        let frame2 = design.createPlane(deriving: design.currentPlane!)
        let b = frame2.create(TestType)
        try design.accept(frame2)
        
        #expect(!design.currentPlane!.contains(discardedObject.objectID))
        #expect(design.currentPlane!.contains(b.objectID))
        
        #expect(design.currentPlaneID == frame2.id)
        #expect(design.versionHistory == [v0, frame2.id])
        #expect(design.undoList == [v0])
        #expect(design.redoList == [])
        #expect(!design.containsPlane(discardedFrame.id))
        #expect(design.snapshot(discardedObject.snapshotID) == nil)
    }
    
    @Test func constraintViolationAccept() throws {
        let constraint = Constraint(name: "test",
                                    match: .any,
                                    requirement: RejectAll())
        let metamodel = Metamodel(merging: TestMetamodel,
                                  Metamodel(constraints: [constraint]))
        let design = Design(metamodel: metamodel)
        
        let frame = design.createPlane()
        let a = frame.createNode(TestNodeType)
        let b = frame.createNode(TestNodeType)
        
        #expect {
            try design.accept(frame)
        } throws: {
            let error = try #require($0 as? PlaneValidationError,
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
        let frame = design.createPlane()
        try design.accept(frame)
        try design.accept(design.createPlane())
        try design.accept(design.createPlane())
        
        // Sanity first
        #expect(design.undoList.count == 2)
        #expect(design.undoList.contains(frame.id))
        
        design.removePlane(frame.id)
        #expect(design.undoList.count == 1)
        #expect(!design.undoList.contains(frame.id))
    }
    
    @Test func acceptNamedFrame() throws {
        let frame = design.createPlane()
        try design.accept(frame, replacingName: "app")

        #expect(design.containsPlane(frame.id))
        #expect(!design.redoList.contains(frame.id))
        #expect(!design.undoList.contains(frame.id))
        #expect(design.plane(name: "app")?.id == frame.id)
    }
    @Test func acceptAndReplaceNamedFrame() throws {
        let frameOld = design.createPlane()
        try design.accept(frameOld, replacingName: "app")
        let frame = design.createPlane()
        try design.accept(frame, replacingName: "app")

        #expect(!design.containsPlane(frameOld.id))
        #expect(design.containsPlane(frame.id))
        #expect(design.plane(name: "app")?.id == frame.id)
    }
    
    @Test func removeNamedFrame() throws {
        let frame = design.createPlane()
        try design.accept(frame, replacingName: "app")
        design.removePlane(frame.id)
        
        #expect(design.plane(name: "app")?.id == nil)
    }

}
