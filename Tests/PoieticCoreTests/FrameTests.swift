//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Foundation
import XCTest
@testable import PoieticCore

final class MutableFrameTests: XCTestCase {
    var memory: ObjectMemory!
    
    override func setUp() {
        memory = ObjectMemory()
    }
    
    func testDeriveObjectWithStructure() throws {
        let originalFrame = memory.deriveFrame()
        
        let original = memory.createSnapshot(TestNodeType)
        originalFrame.insert(original, owned: true)
        try memory.accept(originalFrame)
        
        let derivedFrame = memory.deriveFrame(original: originalFrame.id)
        let derived = derivedFrame.mutableObject(original.id)
        XCTAssertEqual(original.structure, derived.structure)
    }
    
    func testDeriveObjectWithChildrenParent() throws {
        let frame = memory.deriveFrame()
        
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)
        frame.setParent(obj, to: parent)
        frame.setParent(child, to: obj)
        try memory.accept(frame)
        
        let derivedFrame = memory.deriveFrame(original: frame.id)
        let derivedObj = derivedFrame.mutableObject(obj)
        XCTAssertEqual(derivedObj.parent, parent)
        XCTAssertEqual(derivedObj.children, [child])

        let derivedParent = derivedFrame.mutableObject(parent)
        XCTAssertEqual(derivedParent.parent, nil)
        XCTAssertEqual(derivedParent.children, [obj])

        let derivedChild = derivedFrame.mutableObject(child)
        XCTAssertEqual(derivedChild.parent, obj)
        XCTAssertEqual(derivedChild.children, [])
    }
    
    func testSetAttribute() throws {
        let frame = memory.deriveFrame()
        let id = frame.create(TestType, 
                              attributes: ["text": ForeignValue("before")])
        
        let obj = frame.object(id)
        
        obj.setAttribute(value: ForeignValue("after"), forKey: "text")
        
        let value = obj.attribute(forKey: "text")
        XCTAssertEqual(try value?.stringValue(), "after")
        XCTAssertEqual(obj.attribute(forKey: "text"), "after")
    }
    func testModifyAttribute() throws {
        let original = memory.deriveFrame()
        
        let a = original.create(TestType,
                                attributes: ["text": ForeignValue("before")],
                                components: [])
        try memory.accept(original)
        
        let a2 = memory.currentFrame.object(a)
        XCTAssertEqual(a2["text"], "before")
        
        let altered = memory.deriveFrame()
        let alt_obj = altered.mutableObject(a)
        alt_obj["text"] = "after"
        
        XCTAssertTrue(altered.hasChanges)

        let a3 = altered.object(a)
        XCTAssertEqual(a3["text"], "after")
        
        try memory.accept(altered)
        
        let aCurrentAlt = memory.currentFrame.object(a)
        XCTAssertEqual(aCurrentAlt["text"], "after")
        
        let aOriginal = memory.frame(original.id)!.object(a)
        XCTAssertEqual(aOriginal["text"], "before")
    }
    

    func testModifyComponent() throws {
        let original = memory.deriveFrame()
        
        let a = original.create(TestType, 
                                attributes: ["text": "before"])
        try memory.accept(original)
        
        let a2 = memory.currentFrame.object(a)
        XCTAssertEqual(a2["text"], "before")
        
        let altered = memory.deriveFrame()
        let mutable_a = altered.mutableObject(a)
        mutable_a["text"] = "after"
        
        XCTAssertTrue(altered.hasChanges)
        let a3 = altered.object(a)
        XCTAssertEqual(a3["text"], "after")
        
        try memory.accept(altered)
        
        let aCurrentAlt = memory.currentFrame.object(a)
        XCTAssertEqual(aCurrentAlt["text"], "after")
        
        let aOriginal = memory.frame(original.id)!.object(a)
        XCTAssertEqual(aOriginal["text"], "before")
    }
    

    func testMutableObject() throws {
        let original = memory.deriveFrame()
        let id = original.create(TestType)
        let originalSnap = original.object(id)
        try memory.accept(original)
        
        let derived = memory.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertEqual(derivedSnap.id, originalSnap.id)
        XCTAssertNotEqual(derivedSnap.snapshotID, originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutableObject(id)
        XCTAssertIdentical(derivedSnap, derivedSnap2)
    }

    func testMutableObjectCopyAttributes() throws {
        let original = memory.deriveFrame()
        let id = original.create(TestType, attributes: ["text": "hello"])
        try memory.accept(original)
        
        let derived = memory.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertEqual(derivedSnap["text"], "hello")
    }

    func testRemoveObjectCascading() throws {
        let frame = memory.deriveFrame()
        
        let node1 = memory.createSnapshot(TestNodeType)
        frame.insert(node1, owned: true)
        
        let node2 = memory.createSnapshot(TestNodeType)
        frame.insert(node2, owned: true)
        
        let edge = memory.createSnapshot(TestEdgeType,
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
    
    func testFrameMutableObjectRemovesPreviousSnapshot() throws {
        let original = memory.deriveFrame()
        let id = original.create(TestType)
        let originalSnap = original.object(id)
        try memory.accept(original)
        
        let derived = memory.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertFalse(derived.snapshots.contains(where: { $0.snapshotID == originalSnap.snapshotID }))
        XCTAssertTrue(derived.snapshots.contains(where: { $0.snapshotID == derivedSnap.snapshotID }))
        XCTAssertFalse(derived.snapshotIDs.contains(originalSnap.snapshotID))
        XCTAssertTrue(derived.snapshotIDs.contains(derivedSnap.snapshotID))
    }

    func testAddChild() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)
        
        XCTAssertEqual(frame.object(a).children, [b, c])
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, a)
    }
    
    func testRemoveChild() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)
        
        frame.removeChild(c, from: a)
        
        XCTAssertEqual(frame.object(a).children, [b])
        XCTAssertNil(frame.object(c).parent)
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, nil)
    }
    
    func testSetParent() throws {
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.setParent(c, to: a)
        
        XCTAssertEqual(frame.object(a).children, [b, c])
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, a)
        
        frame.setParent(c, to: b)
        
        XCTAssertEqual(frame.object(a).children, [b])
        XCTAssertEqual(frame.object(b).children, [c])
        XCTAssertEqual(frame.object(b).parent, a)
        XCTAssertEqual(frame.object(c).parent, b)
    }
    func testRemoveFromParent() throws {
        // FIXME: Test remove from non-owned parent
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)

        frame.removeFromParent(b)
        XCTAssertNil(frame.object(b).parent)
        XCTAssertEqual(frame.object(a).children, [c])

        frame.removeFromParent(c)
        XCTAssertNil(frame.object(c).parent)
        XCTAssertEqual(frame.object(a).children, [])
    }

    func testRemoveFromUnownedParentMutates() throws {
        // FIXME: Test remove from non-owned parent
        let frame = memory.createFrame()
        
        let p = frame.create(TestType)
        let c1 = frame.create(TestType)
        let c2 = frame.create(TestType)
        
        frame.addChild(c1, to: p)
        frame.addChild(c2, to: p)
        try memory.accept(frame)
        
        let derived = memory.deriveFrame(original: frame.id)
        // A sanity check
        XCTAssertEqual(derived.object(p).snapshotID, frame.object(p).snapshotID)

        // A the real check
        derived.removeFromParent(c1)
        let derivedP = derived.object(p)
        XCTAssertNotEqual(derivedP.snapshotID, frame.object(p).snapshotID)

        // A sanity check
        derived.removeFromParent(c2)
        XCTAssertEqual(derivedP.snapshotID, derived.object(p).snapshotID)
    }

    
    func testRemoveCascadingChildren() throws {
        // a - b - c
        // d - e - f
        //
        let frame = memory.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        let d = frame.create(TestType)
        let e = frame.create(TestType)
        let f = frame.create(TestType)

        frame.addChild(b, to: a)
        frame.addChild(c, to: b)
        frame.addChild(e, to: d)
        frame.addChild(f, to: e)

        frame.removeCascading(b)
        XCTAssertFalse(frame.contains(b))
        XCTAssertFalse(frame.contains(c))
        XCTAssertFalse(frame.object(a).children.contains(b))

        frame.removeCascading(d)
        XCTAssertFalse(frame.contains(d))
        XCTAssertFalse(frame.contains(e))
        XCTAssertFalse(frame.contains(f))
    }
    
    func testBrokenReferences() throws {
        let frame = memory.createFrame()
        let a = memory.createSnapshot(TestEdgeType, 
                                      id: 5,
                                      structure: .edge(30, 40))
        a.parent = 10
        a.children = [20]
        frame.unsafeInsert(a, owned: true)

        let refs = frame.brokenReferences()
        
        XCTAssertEqual(refs.count, 4)
        XCTAssertTrue(refs.contains(10))
        XCTAssertTrue(refs.contains(20))
        XCTAssertTrue(refs.contains(30))
        XCTAssertTrue(refs.contains(40))
    }
    
    func testSomethingIDK() throws {
        let frame = memory.createFrame()
        // Edge with children
        let a = frame.create(TestNodeType)
        let b = frame.create(TestNodeType)
        let c = frame.create(TestNodeType)
        let e = frame.create(TestEdgeType, structure: .edge(a, a))
        frame.addChild(b, to: e)
        frame.addChild(c, to: e)
        
        frame.removeCascading(a)
        XCTAssertEqual(frame.snapshots.map {$0.id}, [])
    }
    
}
