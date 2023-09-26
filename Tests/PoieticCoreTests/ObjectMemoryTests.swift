//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

import XCTest
@testable import PoieticCore

final class ObjectMemoryTests: XCTestCase {
    func testEmpty() throws {
        let db = ObjectMemory()
        
        XCTAssertNil(db.currentFrameID)
        
        let frame = db.deriveFrame()
        
        try db.accept(frame)
        
        XCTAssertFalse(frame.state.isMutable)
        XCTAssertTrue(db.containsFrame(frame.id))
    }
    
    func testSimpleAccept() throws {
        let db = ObjectMemory()
        
        let frame = db.deriveFrame()
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        
        XCTAssertTrue(frame.contains(a))
        XCTAssertTrue(frame.contains(b))
        XCTAssertTrue(frame.hasChanges)
        XCTAssertEqual(db.versionHistory.count, 0)
        
        try db.accept(frame)
        
        XCTAssertEqual(db.versionHistory, [frame.id])
        XCTAssertEqual(db.currentFrame.id, frame.id)
        XCTAssertTrue(db.currentFrame.contains(a))
        XCTAssertTrue(db.currentFrame.contains(b))
    }
    
    func testMakeObjectFrozenAfterAccept() throws {
        let db = ObjectMemory()
        let frame = db.deriveFrame()
        let a = frame.create(TestType)
        try db.accept(frame)
        
        let obj = db.currentFrame.object(a)
        XCTAssertEqual(obj.state, VersionState.frozen)
    }
    
    func testDiscard() throws {
        let db = ObjectMemory()
        let frame = db.deriveFrame()
        let _ = frame.create(TestType)
        
        db.discard(frame)
        
        XCTAssertEqual(db.versionHistory.count, 0)
        XCTAssertEqual(frame.state, VersionState.frozen)
    }
    
    func testRemoveObject() throws {
        let db = ObjectMemory()
        let originalFrame = db.deriveFrame()
        
        let a = originalFrame.create(TestType)
        try db.accept(originalFrame)
        
        let originalVersion = db.currentFrameID
        
        let removalFrame = db.deriveFrame()
        XCTAssertTrue(db.currentFrame.contains(a))
        removalFrame.removeCascading(a)
        XCTAssertTrue(removalFrame.hasChanges)
        XCTAssertFalse(removalFrame.contains(a))
        
        try db.accept(removalFrame)
        XCTAssertEqual(db.currentFrame.id, removalFrame.id)
        XCTAssertFalse(db.currentFrame.contains(a))
        
        let original2 = db.frame(originalVersion!)!
        XCTAssertTrue(original2.contains(a))
    }
    func testRemoveObjectCascading() throws {
        let db = ObjectMemory()
        let frame = db.deriveFrame()
        
        let node1 = db.createSnapshot(TestNodeType)
        frame.insert(node1, owned: true)
        
        let node2 = db.createSnapshot(TestNodeType)
        frame.insert(node2, owned: true)
        
        let edge = db.createSnapshot(TestEdgeType,
                                     structure: .edge(node1.id, node2.id))
        frame.insert(edge, owned: true)
        
        let removed = frame.removeCascading(node1.id)
        XCTAssertEqual(removed.count, 2)
        XCTAssertTrue(removed.contains(edge.id))
        XCTAssertTrue(removed.contains(node1.id))

        XCTAssertFalse(frame.contains(node1.id))
        XCTAssertFalse(frame.contains(edge.id))
        XCTAssertTrue(frame.contains(node2.id))
    }
    
    func testFrameMutableObject() throws {
        let db = ObjectMemory()
        let original = db.deriveFrame()
        let id = original.create(TestType)
        let originalSnap = original.object(id)
        try db.accept(original)
        
        let derived = db.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertEqual(derivedSnap.id, originalSnap.id)
        XCTAssertNotEqual(derivedSnap.snapshotID, originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutableObject(id)
        XCTAssertIdentical(derivedSnap, derivedSnap2)
    }
    
    func testFrameMutableObjectRemovesPreviousSnapshot() throws {
        let db = ObjectMemory()
        let original = db.deriveFrame()
        let id = original.create(TestType)
        let originalSnap = original.object(id)
        try db.accept(original)
        
        let derived = db.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertFalse(derived.snapshots.contains(where: { $0.snapshotID == originalSnap.snapshotID }))
        XCTAssertTrue(derived.snapshots.contains(where: { $0.snapshotID == derivedSnap.snapshotID }))
        XCTAssertFalse(derived.snapshotIDs.contains(originalSnap.snapshotID))
        XCTAssertTrue(derived.snapshotIDs.contains(derivedSnap.snapshotID))
    }
    
    func testModifyAttribute() throws {
        let db = ObjectMemory()
        let original = db.deriveFrame()
        
        let a = original.create(TestType, components: [TestComponent(text: "before")])
        try db.accept(original)
        
        let a2 = db.currentFrame.object(a)
        XCTAssertEqual(a2[TestComponent.self]!.text, "before")
        
        let altered = db.deriveFrame()
        altered.setComponent(a, component: TestComponent(text: "after"))
        
        XCTAssertTrue(altered.hasChanges)
        let a3 = altered.object(a)
        XCTAssertEqual(a3[TestComponent.self]!.text, "after")
        
        try db.accept(altered)
        
        let aCurrentAlt = db.currentFrame.object(a)
        XCTAssertEqual(aCurrentAlt[TestComponent.self]!.text, "after")
        
        let aOriginal = db.frame(original.id)!.object(a)
        XCTAssertEqual(aOriginal[TestComponent.self]!.text, "before")
    }
    
    func testUndo() throws {
        let db = ObjectMemory()
        try db.accept(db.createFrame())
        let v0 = db.currentFrameID!
        
        let frame1 = db.deriveFrame()
        let a = frame1.create(TestType)
        try db.accept(frame1)
        
        let frame2 = db.deriveFrame()
        let b = frame2.create(TestType)
        try db.accept(frame2)
        
        XCTAssertTrue(db.currentFrame.contains(a))
        XCTAssertTrue(db.currentFrame.contains(b))
        XCTAssertEqual(db.versionHistory, [v0, frame1.id, frame2.id])
        
        db.undo(to: frame1.id)
        
        XCTAssertEqual(db.currentFrameID, frame1.id)
        XCTAssertEqual(db.undoableFrames, [v0])
        XCTAssertEqual(db.redoableFrames, [frame2.id])
        
        db.undo(to: v0)
        
        XCTAssertEqual(db.currentFrameID, v0)
        XCTAssertEqual(db.undoableFrames, [])
        XCTAssertEqual(db.redoableFrames, [frame1.id, frame2.id])
        
        XCTAssertFalse(db.currentFrame.contains(a))
        XCTAssertFalse(db.currentFrame.contains(b))
    }
    
    func testUndoProperty() throws {
        let db = ObjectMemory()
        
        let frame1 = db.deriveFrame()
        let a = frame1.create(TestType, components: [TestComponent(text: "before")])
        try db.accept(frame1)
        
        let frame2 = db.deriveFrame()
        frame2.setComponent(a, component: TestComponent(text: "after"))
        
        try db.accept(frame2)
        
        db.undo(to: frame1.id)
        let altered = db.currentFrame.object(a)
        XCTAssertEqual(altered[TestComponent.self]!.text, "before")
    }
    
    func testRedo() throws {
        let db = ObjectMemory()
        try db.accept(db.createFrame())
        let v0 = db.currentFrameID!
        
        let frame1 = db.deriveFrame()
        let a = frame1.create(TestType)
        try db.accept(frame1)
        
        let frame2 = db.deriveFrame()
        let b = frame2.create(TestType)
        try db.accept(frame2)
        
        db.undo(to: frame1.id)
        db.redo(to: frame2.id)
        
        XCTAssertTrue(db.currentFrame.contains(a))
        XCTAssertTrue(db.currentFrame.contains(b))
        
        XCTAssertEqual(db.currentFrameID, frame2.id)
        XCTAssertEqual(db.undoableFrames, [v0, frame1.id])
        XCTAssertEqual(db.redoableFrames, [])
        XCTAssertFalse(db.canRedo)
        
        db.undo(to: v0)
        db.redo(to: frame2.id)
        
        XCTAssertEqual(db.currentFrameID, frame2.id)
        XCTAssertEqual(db.undoableFrames, [v0, frame1.id])
        XCTAssertEqual(db.redoableFrames, [])
        XCTAssertFalse(db.canRedo)
        
        db.undo(to: v0)
        db.redo(to: frame1.id)
        
        XCTAssertEqual(db.currentFrameID, frame1.id)
        XCTAssertEqual(db.undoableFrames, [v0])
        XCTAssertEqual(db.redoableFrames, [frame2.id])
        XCTAssertTrue(db.canRedo)
        
        XCTAssertTrue(db.currentFrame.contains(a))
        XCTAssertFalse(db.currentFrame.contains(b))
    }
    
    func testRedoReset() throws {
        let db = ObjectMemory()
        try db.accept(db.createFrame())
        let v0 = db.currentFrameID!
        
        let frame1 = db.deriveFrame()
        let a = frame1.create(TestType)
        try db.accept(frame1)
        
        db.undo(to: v0)
        
        let frame2 = db.deriveFrame()
        let b = frame2.create(TestType)
        try db.accept(frame2)
        
        XCTAssertEqual(db.currentFrameID, frame2.id)
        XCTAssertEqual(db.versionHistory, [v0, frame2.id])
        XCTAssertEqual(db.undoableFrames, [v0])
        XCTAssertEqual(db.redoableFrames, [])
        
        XCTAssertFalse(db.currentFrame.contains(a))
        XCTAssertTrue(db.currentFrame.contains(b))
    }
    
    func testConstraintViolationAccept() throws {
        // TODO: Change this to non-graph constraint check
        let db = ObjectMemory()
        let frame = db.deriveFrame()
        let graph = frame.mutableGraph
        let a = graph.createNode(TestNodeType)
        let b = graph.createNode(TestNodeType)
        
        let constraint = Constraint(name: "test",
                                    match: AnyPredicate(),
                                    requirement: RejectAll())
        
        // TODO: Test this separately
        try db.addConstraint(constraint)
        
        XCTAssertThrowsError(try db.accept(frame)) {
            
            guard let error = $0 as? ConstraintViolationError else {
                XCTFail("Expected ConstraintViolationError")
                return
            }
            
            XCTAssertEqual(error.violations.count, 1)
            let violation = error.violations[0]
            XCTAssertIdentical(violation.constraint, constraint)
            XCTAssertTrue(violation.objects.contains(a))
            XCTAssertTrue(violation.objects.contains(b))
        }
    }
    
    func testDeriveObjectWithStructure() throws {
        let db = ObjectMemory()
        let originalFrame = db.deriveFrame()
        
        let original = db.createSnapshot(TestNodeType)
        originalFrame.insert(original, owned: true)
        try db.accept(originalFrame)
        
        let derivedFrame = db.deriveFrame(original: originalFrame.id)
        let derived = derivedFrame.mutableObject(original.id)
        XCTAssertEqual(original.structure, derived.structure)
    }
    
    func testSetAttribute() throws {
        let db = ObjectMemory()
        let frame = db.deriveFrame()
        let id = frame.create(TestType, components: [TestComponent(text: "before")])
        
        let obj = frame.object(id)
        
        try obj.setAttribute(value: ForeignValue("after"), forKey: "text")
        
        let comp: TestComponent = obj[TestComponent.self]!
        XCTAssertEqual(comp.text, "after")
        XCTAssertEqual(obj.attribute(forKey: "text"), "after")
    }
}
