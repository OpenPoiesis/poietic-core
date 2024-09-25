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
    var design: Design!
    
    override func setUp() {
        design = Design(metamodel: TestMetamodel)
    }
    
    func testDeriveObjectWithStructure() throws {
        let originalFrame = design.deriveFrame()
        
        let original = design.createSnapshot(TestNodeType)
        originalFrame.insert(original)
        try design.accept(originalFrame)
        
        let derivedFrame = design.deriveFrame(original: originalFrame.id)
        let derived = derivedFrame.mutableObject(original.id)
        XCTAssertEqual(original.structure, derived.structure)
    }
    
    func testDeriveObjectWithChildrenParent() throws {
        let frame = design.deriveFrame()
        
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)
        frame.setParent(obj, to: parent)
        frame.setParent(child, to: obj)
        try design.accept(frame)
        
        let derivedFrame = design.deriveFrame(original: frame.id)
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
        let frame = design.deriveFrame()
        let id = frame.create(TestType, 
                              attributes: ["text": Variant("before")])
        
        let obj = frame[id]
        
        obj.setAttribute(value: Variant("after"), forKey: "text")
        
        let value = obj["text"]
        XCTAssertEqual(try value?.stringValue(), "after")
        XCTAssertEqual(obj["text"], "after")
    }
    func testModifyAttribute() throws {
        let original = design.deriveFrame()
        
        let a = original.create(TestType,
                                attributes: ["text": Variant("before")],
                                components: [])
        try design.accept(original)
        
        let a2 = design.currentFrame.object(a)
        XCTAssertEqual(a2["text"], "before")
        
        let altered = design.deriveFrame()
        let alt_obj = altered.mutableObject(a)
        alt_obj["text"] = "after"
        
        XCTAssertTrue(altered.hasChanges)

        let a3 = altered[a]
        XCTAssertEqual(a3["text"], "after")
        
        try design.accept(altered)
        
        let aCurrentAlt = design.currentFrame.object(a)
        XCTAssertEqual(aCurrentAlt["text"], "after")
        
        let aOriginal = design.frame(original.id)!.object(a)
        XCTAssertEqual(aOriginal["text"], "before")
    }
    

    func testModifyComponent() throws {
        let original = design.deriveFrame()
        
        let a = original.create(TestType, 
                                attributes: ["text": "before"])
        try design.accept(original)
        
        let a2 = design.currentFrame[a]
        XCTAssertEqual(a2["text"], "before")
        
        let altered = design.deriveFrame()
        let mutable_a = altered.mutableObject(a)
        mutable_a["text"] = "after"
        
        XCTAssertTrue(altered.hasChanges)
        let a3 = altered[a]
        XCTAssertEqual(a3["text"], "after")
        
        try design.accept(altered)
        
        let aCurrentAlt = design.currentFrame.object(a)
        XCTAssertEqual(aCurrentAlt["text"], "after")
        
        let aOriginal = design.frame(original.id)!.object(a)
        XCTAssertEqual(aOriginal["text"], "before")
    }
    

    func testMutableObject() throws {
        let original = design.deriveFrame()
        let id = original.create(TestType)
        let originalSnap = original[id]
        try design.accept(original)
        
        let derived = design.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertEqual(derivedSnap.id, originalSnap.id)
        XCTAssertNotEqual(derivedSnap.snapshotID, originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutableObject(id)
        XCTAssertIdentical(derivedSnap, derivedSnap2)
    }

    func testMutableObjectCopyAttributes() throws {
        let original = design.deriveFrame()
        let id = original.create(TestType, attributes: ["text": "hello"])
        try design.accept(original)
        
        let derived = design.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertEqual(derivedSnap["text"], "hello")
    }

    func testRemoveObjectCascading() throws {
        let frame = design.deriveFrame()
        
        let node1 = design.createSnapshot(TestNodeType)
        frame.insert(node1)
        
        let node2 = design.createSnapshot(TestNodeType)
        frame.insert(node2)
        
        let edge = design.createSnapshot(TestEdgeType,
                                     structure: .edge(node1.id, node2.id))
        frame.insert(edge)
        
        let removed = frame.removeCascading(node1.id)
        XCTAssertEqual(removed.count, 2)
        XCTAssertTrue(removed.contains(edge.id))
        XCTAssertTrue(removed.contains(node1.id))

        XCTAssertFalse(frame.contains(node1.id))
        XCTAssertFalse(frame.contains(edge.id))
        XCTAssertTrue(frame.contains(node2.id))
    }
    
    func testFrameMutableObjectRemovesPreviousSnapshot() throws {
        let original = design.deriveFrame()
        let id = original.create(TestType)
        let originalSnap = original[id]
        try design.accept(original)
        
        let derived = design.deriveFrame()
        let derivedSnap = derived.mutableObject(id)
        
        XCTAssertFalse(derived.snapshots.contains(where: { $0.snapshotID == originalSnap.snapshotID }))
        XCTAssertTrue(derived.snapshots.contains(where: { $0.snapshotID == derivedSnap.snapshotID }))
        XCTAssertFalse(derived.snapshotIDs.contains(originalSnap.snapshotID))
        XCTAssertTrue(derived.snapshotIDs.contains(derivedSnap.snapshotID))
    }

    func testAddChild() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)
        
        XCTAssertEqual(frame[a].children, [b, c])
        XCTAssertEqual(frame[b].parent, a)
        XCTAssertEqual(frame[c].parent, a)
    }
    
    func testRemoveChild() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)
        
        frame.removeChild(c, from: a)
        
        XCTAssertEqual(frame[a].children, [b])
        XCTAssertNil(frame[c].parent)
        XCTAssertEqual(frame[b].parent, a)
        XCTAssertEqual(frame[c].parent, nil)
    }
    
    func testSetParent() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.setParent(c, to: a)
        
        XCTAssertEqual(frame[a].children, [b, c])
        XCTAssertEqual(frame[b].parent, a)
        XCTAssertEqual(frame[c].parent, a)
        
        frame.setParent(c, to: b)
        
        XCTAssertEqual(frame[a].children, [b])
        XCTAssertEqual(frame[b].children, [c])
        XCTAssertEqual(frame[b].parent, a)
        XCTAssertEqual(frame[c].parent, b)
    }
    func testRemoveFromParent() throws {
        // TODO: Test remove from non-owned parent
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b, to: a)
        frame.addChild(c, to: a)

        frame.removeFromParent(b)
        XCTAssertNil(frame[b].parent)
        XCTAssertEqual(frame[a].children, [c])

        frame.removeFromParent(c)
        XCTAssertNil(frame[c].parent)
        XCTAssertEqual(frame[a].children, [])
    }

    func testRemoveFromUnownedParentMutates() throws {
        // TODO: Test remove from non-owned parent
        let frame = design.createFrame()
        
        let p = frame.create(TestType)
        let c1 = frame.create(TestType)
        let c2 = frame.create(TestType)
        
        frame.addChild(c1, to: p)
        frame.addChild(c2, to: p)
        try design.accept(frame)
        
        let derived = design.deriveFrame(original: frame.id)
        // A sanity check
        XCTAssertEqual(derived[p].snapshotID, frame[p].snapshotID)

        // A the real check
        derived.removeFromParent(c1)
        let derivedP = derived[p]
        XCTAssertNotEqual(derivedP.snapshotID, frame[p].snapshotID)

        // A sanity check
        derived.removeFromParent(c2)
        XCTAssertEqual(derivedP.snapshotID, derived[p].snapshotID)
    }

    
    func testRemoveCascadingChildren() throws {
        // a - b - c
        // d - e - f
        //
        let frame = design.createFrame()
        
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
        XCTAssertFalse(frame[a].children.contains(b))

        frame.removeCascading(d)
        XCTAssertFalse(frame.contains(d))
        XCTAssertFalse(frame.contains(e))
        XCTAssertFalse(frame.contains(f))
    }
    
    func testBrokenReferences() throws {
        let frame = design.createFrame()
        let a = design.createSnapshot(TestEdgeType, 
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
        let frame = design.createFrame()
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
