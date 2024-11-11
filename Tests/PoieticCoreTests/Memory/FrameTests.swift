//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Foundation
import XCTest
@testable import PoieticCore

final class TransientFrameTests: XCTestCase {
    var design: Design!
    
    override func setUp() {
        design = Design(metamodel: TestMetamodel)
    }
    
    func testDeriveObjectWithStructure() throws {
        let  frame = design.createFrame()
        
        let original = frame.create(TestNodeType)
        let originalFrame = try design.accept(frame)
        
        let derivedFrame = design.createFrame(deriving: originalFrame)
        let derived = derivedFrame.mutate(original.id)
        XCTAssertEqual(original.structure, derived.structure)
    }
    
    func testAcceptPreservesParentChild() throws {
        let frame = design.createFrame()
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)
        frame.setParent(obj.id, to: parent.id)
        frame.setParent(child.id, to: obj.id)
        
        let accepted = try design.accept(frame)
        XCTAssertEqual(accepted[obj.id].children, obj.children)
        XCTAssertEqual(accepted[obj.id].parent, obj.parent)
    }
    
    func testDeriveObjectWithChildrenParent() throws {
        let frame = design.createFrame()
        
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)
        frame.setParent(obj.id, to: parent.id)
        frame.setParent(child.id, to: obj.id)
        
        let derivedFrame = design.createFrame(deriving: try design.accept(frame))
        let derivedObj = derivedFrame.mutate(obj.id)
        XCTAssertEqual(derivedObj.parent, parent.id)
        XCTAssertEqual(derivedObj.children, [child.id])

        let derivedParent = derivedFrame.mutate(parent.id)
        XCTAssertEqual(derivedParent.parent, nil)
        XCTAssertEqual(derivedParent.children, [obj.id])

        let derivedChild = derivedFrame.mutate(child.id)
        XCTAssertEqual(derivedChild.parent, obj.id)
        XCTAssertEqual(derivedChild.children, [])
    }
    
    func testSetAttribute() throws {
        let frame = design.createFrame()
        let obj = frame.create(TestType, attributes: ["text": Variant("before")])
        
        obj.setAttribute(value: Variant("after"), forKey: "text")
        
        let value = obj["text"]
        XCTAssertEqual(try value?.stringValue(), "after")
        XCTAssertEqual(obj["text"], "after")
    }
    func testModifyAttribute() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType,
                             attributes: ["text": Variant("before")])
        let original = try design.accept(frame)
        
        let frame2 = design.createFrame(deriving: original)
        let alt_obj = frame2.mutate(a.id)
        alt_obj["text"] = "after"
        
        XCTAssertTrue(frame2.hasChanges)

        let altered = try design.accept(frame2)
        
        XCTAssertEqual(altered[a.id]["text"], "after")
        
        let aOriginal = design.frame(original.id)![a.id]
        XCTAssertEqual(aOriginal["text"], "before")
    }
    

    func testModifyComponent() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType, components: [TestComponent(text: "before")])
        let original = try design.accept(frame)
        
        let frame2 = design.createFrame(deriving: original)
        let mutable_a = frame2.mutate(a.id)
        mutable_a[TestComponent.self] = TestComponent(text: "after")
        
        XCTAssertTrue(frame2.hasChanges)

        let altered = try design.accept(frame2)
        let comp: TestComponent = altered[a.id][TestComponent.self]!
        XCTAssertEqual(comp.text, "after")
        
        let aOriginal = design.frame(original.id)![a.id]
        let compOrignal: TestComponent = aOriginal[TestComponent.self]!
        XCTAssertEqual(compOrignal.text, "before")
    }
    

    func testMutableObject() throws {
        let original = design.createFrame()
        let obj = original.create(TestType)
        let originalSnap = original[obj.id]
        try design.accept(original)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(obj.id)
        
        XCTAssertEqual(derivedSnap.id, originalSnap.id)
        XCTAssertNotEqual(derivedSnap.snapshotID, originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutate(obj.id)
        XCTAssertIdentical(derivedSnap, derivedSnap2)
    }

    func testMutableObjectCopyAttributes() throws {
        let original = design.createFrame()
        let obj = original.create(TestType, attributes: ["text": "hello"])
        try design.accept(original)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(obj.id)
        
        XCTAssertEqual(derivedSnap["text"], "hello")
    }

    func testRemoveObjectCascading() throws {
        let frame = design.createFrame()
        
        let node1 = frame.create(TestNodeType)
        let node2 = frame.create(TestNodeType)
        let edge = frame.create(TestEdgeType, structure: .edge(node1.id, node2.id))
        
        let removed = frame.removeCascading(node1.id)
        XCTAssertEqual(removed.count, 2)
        XCTAssertTrue(removed.contains(edge.id))
        XCTAssertTrue(removed.contains(node1.id))

        XCTAssertFalse(frame.contains(node1.id))
        XCTAssertFalse(frame.contains(edge.id))
        XCTAssertTrue(frame.contains(node2.id))
    }

    func testOnlyOriginalsRemoved() throws {
        let frame = design.createFrame()
        let originalNode = frame.create(TestNodeType)
        let original = try design.accept(frame)
        
        let trans = design.createFrame(deriving: original)
        trans.removeCascading(originalNode.id)
        XCTAssertEqual(trans.snapshotIDs.count, 0)

        let newNode = trans.create(TestNodeType)
        XCTAssertEqual(trans.removedObjects.count, 1)
        XCTAssertFalse(trans.removedObjects.contains(newNode.id))
        XCTAssertTrue(trans.removedObjects.contains(originalNode.id))

        XCTAssertFalse(trans.contains(originalNode.id))
        XCTAssertTrue(trans.contains(newNode.id))
    }

    func testRemoveCreate() throws {
        let frame = design.createFrame()
        let originalNode = frame.create(TestNodeType)
        let original = try design.accept(frame)

        let trans = design.createFrame(deriving: original)

        trans.removeCascading(originalNode.id)
        XCTAssertEqual(trans.removedObjects.count, 1)
        XCTAssertTrue(trans.removedObjects.contains(originalNode.id))

        let newNode = trans.create(TestNodeType, id: originalNode.id)

        XCTAssertEqual(trans.snapshotIDs.count, 1)
        XCTAssertEqual(trans.removedObjects.count, 0)
        XCTAssertTrue(trans.contains(newNode.id))
    }

    func testFrameMutableObjectRemovesPreviousSnapshot() throws {
        let original = design.createFrame()
        let originalSnap = original.create(TestType)
        try design.accept(original)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(originalSnap.id)
        
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
        
        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: a.id)
        
        XCTAssertEqual(a.children, [b.id, c.id])
        XCTAssertEqual(b.parent, a.id)
        XCTAssertEqual(c.parent, a.id)
    }
    
    func testRemoveChild() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: a.id)
        
        frame.removeChild(c.id, from: a.id)
        
        XCTAssertEqual(a.children, [b.id])
        XCTAssertNil(c.parent)
        XCTAssertEqual(b.parent, a.id)
        XCTAssertEqual(c.parent, nil)
    }
    
    func testSetParent() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.setParent(c.id, to: a.id)
        
        XCTAssertEqual(a.children, [b.id, c.id])
        XCTAssertEqual(b.parent, a.id)
        XCTAssertEqual(c.parent, a.id)
        
        frame.setParent(c.id, to: b.id)
        
        XCTAssertEqual(a.children, [b.id])
        XCTAssertEqual(b.children, [c.id])
        XCTAssertEqual(b.parent, a.id)
        XCTAssertEqual(c.parent, b.id)
    }
    func testRemoveFromParent() throws {
        let frame = design.createFrame()
        
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: a.id)

        frame.removeFromParent(b.id)
        XCTAssertNil(b.parent)
        XCTAssertEqual(a.children, [c.id])

        frame.removeFromParent(c.id)
        XCTAssertNil(c.parent)
        XCTAssertEqual(a.children, [])
    }

    func testRemoveFromUnownedParentMutates() throws {
        let frame = design.createFrame()
        
        let p = frame.create(TestType)
        let c1 = frame.create(TestType)
        let c2 = frame.create(TestType)
        
        frame.addChild(c1.id, to: p.id)
        frame.addChild(c2.id, to: p.id)

        let accepted = try design.accept(frame)
        let derived = design.createFrame(deriving: accepted)
        derived.removeFromParent(c1.id)

        let derivedP = derived[p.id]
        XCTAssertNotEqual(derivedP.snapshotID, p.snapshotID)
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

        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: b.id)
        frame.addChild(e.id, to: d.id)
        frame.addChild(f.id, to: e.id)

        frame.removeCascading(b.id)
        XCTAssertFalse(frame.contains(b.id))
        XCTAssertFalse(frame.contains(c.id))
        XCTAssertFalse(frame[a.id].children.contains(b.id))

        frame.removeCascading(d.id)
        XCTAssertFalse(frame.contains(d))
        XCTAssertFalse(frame.contains(e))
        XCTAssertFalse(frame.contains(f))
    }
    
    func testBrokenReferences() throws {
        let frame = design.createFrame()
        let a = frame.create(TestEdgeType, id: 5, structure: .edge(30, 40))
        a.parent = 10
        a.children = [20]

        let refs = frame.brokenReferences()
        
        XCTAssertEqual(refs.count, 4)
        XCTAssertTrue(refs.contains(10))
        XCTAssertTrue(refs.contains(20))
        XCTAssertTrue(refs.contains(30))
        XCTAssertTrue(refs.contains(40))
    }
    
    func testRejectMissingReferences() throws {
        let frame = design.createFrame()
        frame.create(TestEdgeType, id: 10, structure: .edge(900, 901))
        frame.create(TestType, id: 20, parent: 902, children: [903])

        XCTAssertThrowsError(try frame.accept()) {
            guard $0 as? TransientFrameError != nil else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            
            XCTAssertEqual(frame.brokenReferences().sorted(), [900, 901, 902, 903])
        }

    }

    func testRejectBrokenParentChild() throws {
        let frame = design.createFrame()
        frame.create(TestType, id: 10, children: [20])
        frame.create(TestType, id: 20, parent: 30)
        frame.create(TestType, id: 30)

        XCTAssertThrowsError(try frame.accept()) {
            guard let error = $0 as? TransientFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error, .brokenParentChild)
        }
    }
    
    func testRejectBrokenParentNoChild() throws {
        let frame = design.createFrame()
        frame.create(TestType, id: 10, parent: 30)
        frame.create(TestType, id: 30)

        XCTAssertThrowsError(try frame.accept()) {
            guard let error = $0 as? TransientFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error, .brokenParentChild)
        }

    }
    func testRejectBrokenParentChildCycle() throws {
        let frame = design.createFrame()
        frame.create(TestType, id: 10, parent: 30, children: [30])
        frame.create(TestType, id: 30, parent: 10, children: [10])

        XCTAssertThrowsError(try frame.accept()) {
            guard let error = $0 as? TransientFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error, .brokenParentChild)
        }

    }
    func testRejectEdgeEndpointNotANOde() throws {
        let frame = design.createFrame()
        frame.create(TestEdgeType, id: 10, structure: .edge(20, 20))
        frame.create(TestType, id: 20)

        XCTAssertThrowsError(try frame.accept()) {
            guard let error = $0 as? TransientFrameError else {
                XCTFail("Got unexpected error: \($0)")
                return
            }
            XCTAssertEqual(error, .edgeEndpointNotANode)
        }

    }

}
