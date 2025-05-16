//
//  TransientFrameTests.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Testing
@testable import PoieticCore

@Suite struct TransientFrameTest {
    let design: Design
    let frame: TransientFrame
    
    init() throws {
        design = Design(metamodel: TestMetamodel)
        frame = design.createFrame()
    }
   
    @Test func create() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        
        #expect(frame.contains(a.id))
        #expect(frame.contains(b.id))
        #expect(frame.hasChanges)
    }

    @Test func defaultValueTrait() {
        let a = frame.create(TestTypeNoDefault)
        #expect(a["text"] == nil)

        let b = frame.create(TestTypeWithDefault)
        #expect(b["text"] == "default")
    }
    
    @Test func defaultValueTraitError() {
        let a = frame.create(TestTypeNoDefault)
        let b = frame.create(TestTypeWithDefault)

        #expect {
            try design.validate(try design.accept(frame))
        } throws: {
            guard let error = $0 as? FrameValidationError else {
                Issue.record("Expected FrameValidationError")
                return false
            }
            guard let objErrors = error.objectErrors[a.id] else {
                Issue.record("Expected errors for object 'a'")
                return false
            }
            

            return error.violations.count == 0
                    && error.objectErrors.count == 1
                    && objErrors.first == .missingTraitAttribute(TestTraitNoDefault.attributes[0], "Test")
                    && error.objectErrors[b.id] == nil
        }
    }

    @Test func derivedStructureIsPreserved() throws {
        let original = frame.create(TestNodeType)
        let originalFrame = try design.accept(frame)
        
        let derivedFrame = design.createFrame(deriving: originalFrame)
        let derived = derivedFrame.mutate(original.id)

        #expect(original.structure == derived.structure)
    }

    // MARK: Basics
    
    @Test func setAttribute() throws {
        let obj = frame.create(TestType, attributes: ["text": Variant("before")])
        
        obj.setAttribute(value: Variant("after"), forKey: "text")
        
        let value = obj["text"]
        #expect(try value?.stringValue() == "after")
        #expect(obj["text"] == "after")
    }
    
    // Mutate
    
    @Test func mutateBasicBehavior() throws {
        let obj = frame.create(TestType)
        let originalSnap = frame[obj.id]
        try design.accept(frame)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(obj.id)
        
        #expect(derivedSnap.id == originalSnap.id)
        #expect(derivedSnap.snapshotID != originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutate(obj.id)
        #expect(derivedSnap === derivedSnap2)
    }

    @Test func mutatePreservesAttributes() throws {
        let obj = frame.create(TestType, attributes: ["text": "hello"])
        try design.accept(frame)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(obj.id)
        
        #expect(derivedSnap["text"] == "hello")
    }
    

    @Test func originalValuePreservedOnMutate() throws {
        let object = frame.create(TestType, attributes: ["text": Variant("before")])
        let original = try design.accept(frame)
        
        let frame2 = design.createFrame(deriving: original)
        let changedObject = frame2.mutate(object.id)
        changedObject["text"] = "after"
        
        #expect(frame2.hasChanges)

        let changedFrame = try design.accept(frame2)
        
        #expect(changedFrame[object.id]["text"] == "after")
        
        let originalObject = design.frame(original.id)![object.id]
        #expect(originalObject["text"] == "before")
    }
    

    @Test func originalComponentPreservedOnMutate() throws {
        let object = frame.create(TestType, components: [TestComponent(text: "before")])
        let original = try design.accept(frame)
        
        let frame2 = design.createFrame(deriving: original)
        let changedObject = frame2.mutate(object.id)
        changedObject[TestComponent.self] = TestComponent(text: "after")
        
        #expect(frame2.hasChanges)

        let changedFrame = try design.accept(frame2)
        let comp: TestComponent = changedFrame[object.id][TestComponent.self]!
        #expect(comp.text == "after")
        
        let originalObject = design.frame(original.id)![object.id]
        let compOrignal: TestComponent = originalObject[TestComponent.self]!
        #expect(compOrignal.text == "before")
    }
    
    @Test func removeObjectCascading() throws {
        let node1 = frame.create(TestNodeType)
        let node2 = frame.create(TestNodeType)
        let edge = frame.create(TestEdgeType, structure: .edge(node1.id, node2.id))
        
        let removed = frame.removeCascading(node1.id)
        #expect(removed.count == 2)
        #expect(removed.contains(edge.id))
        #expect(removed.contains(node1.id))

        #expect(!frame.contains(node1.id))
        #expect(!frame.contains(edge.id))
        #expect(frame.contains(node2.id))
    }

    @Test func onlyOriginalsRemoved() throws {
        let originalNode = frame.create(TestNodeType)
        let original = try design.accept(frame)
        
        let trans = design.createFrame(deriving: original)
        #expect(trans.contains(snapshotID: originalNode.snapshotID))
        trans.removeCascading(originalNode.id)
        #expect(!trans.contains(snapshotID: originalNode.snapshotID))

        let newNode = trans.create(TestNodeType)

        #expect(trans.removedObjects.count == 1)
        #expect(!trans.removedObjects.contains(newNode.id))
        #expect(trans.removedObjects.contains(originalNode.id))

        #expect(!trans.contains(originalNode.id))
        #expect(trans.contains(newNode.id))
    }

    @Test func replaceObject() throws {
        let originalNode = frame.create(TestNodeType)
        let original = try design.accept(frame)

        let trans = design.createFrame(deriving: original)

        trans.removeCascading(originalNode.id)
        #expect(trans.removedObjects.count == 1)
        #expect(trans.removedObjects.contains(originalNode.id))

        let newNode = trans.create(TestNodeType, id: originalNode.id)

        #expect(trans.contains(snapshotID: newNode.snapshotID))
        #expect(trans.removedObjects.count == 0)
        #expect(trans.contains(newNode.id))
    }

    @Test func mutableObjectRemovesPreviousSnapshot() throws {
        let original = design.createFrame()
        let originalSnap = original.create(TestType)
        try design.accept(original)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(originalSnap.id)
        #expect(derived.snapshots.count == 1)

        #expect(!derived.snapshots.contains(where: { $0.snapshotID == originalSnap.snapshotID }))
        #expect(derived.snapshots.contains(where: { $0.snapshotID == derivedSnap.snapshotID }))
        #expect(!derived.contains(snapshotID: originalSnap.snapshotID))
        #expect(derived.contains(snapshotID: derivedSnap.snapshotID))
    }

    // MARK: Parent-child
    
    @Test func addChild() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: a.id)
        
        #expect(a.children == [b.id, c.id])
        #expect(b.parent == a.id)
        #expect(c.parent == a.id)
    }
    

    @Test func removeChild() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: a.id)
        
        frame.removeChild(c.id, from: a.id)
        
        #expect(a.children == [b.id])
        #expect(c.parent == nil)
        #expect(b.parent == a.id)
        #expect(c.parent == nil)
    }
    
    @Test func setParent() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.setParent(c.id, to: a.id)
        
        #expect(a.children == [b.id, c.id])
        #expect(b.parent == a.id)
        #expect(c.parent == a.id)
        
        frame.setParent(c.id, to: b.id)
        
        #expect(a.children == [b.id])
        #expect(b.children == [c.id])
        #expect(b.parent == a.id)
        #expect(c.parent == b.id)
    }
    
    @Test func removeFromParent() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.id, to: a.id)
        frame.addChild(c.id, to: a.id)

        frame.removeFromParent(b.id)
        #expect(b.parent == nil)
        #expect(a.children == [c.id])

        frame.removeFromParent(c.id)
        #expect(c.parent == nil)
        #expect(a.children == [])
    }

    @Test func removeFromUnownedParentMutates() throws {
        let p = frame.create(TestType)
        let c1 = frame.create(TestType)
        let c2 = frame.create(TestType)
        
        frame.addChild(c1.id, to: p.id)
        frame.addChild(c2.id, to: p.id)

        let accepted = try design.accept(frame)
        let derived = design.createFrame(deriving: accepted)
        derived.removeFromParent(c1.id)

        let derivedP = derived[p.id]
        #expect(derivedP.snapshotID != p.snapshotID)
    }
    
    @Test func removeCascadingChildren() throws {
        // a - b - c
        // d - e - f
        //
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
        #expect(!frame.contains(b.id))
        #expect(!frame.contains(c.id))
        #expect(!frame[a.id].children.contains(b.id))

        frame.removeCascading(d.id)
        #expect(!frame.contains(d.id))
        #expect(!frame.contains(e.id))
        #expect(!frame.contains(f.id))
    }
    
    @Test func deriveObjectPreservesParentChild() throws {
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)
        frame.setParent(obj.id, to: parent.id)
        frame.setParent(child.id, to: obj.id)
        
        let derivedFrame = design.createFrame(deriving: try design.accept(frame))
        let derivedObj = derivedFrame.mutate(obj.id)

        #expect(derivedObj.parent == parent.id)
        #expect(derivedObj.children == [child.id])

        let derivedParent = derivedFrame.mutate(parent.id)
        #expect(derivedParent.parent == nil)
        #expect(derivedParent.children == [obj.id])

        let derivedChild = derivedFrame.mutate(child.id)
        #expect(derivedChild.parent == obj.id)
        #expect(derivedChild.children == [])
    }
    
    @Test func parentChildIsPreservedOnAccept() throws {
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)

        frame.setParent(obj.id, to: parent.id)
        frame.setParent(child.id, to: obj.id)
        
        let accepted = try design.accept(frame)

        #expect(accepted[obj.id].children == obj.children)
        #expect(accepted[obj.id].parent == obj.parent)
    }

    // MARK: References and Referential Integrity
    
    @Test func brokenReferences() throws {
        frame.create(TestEdgeType, id: 5,
                     structure: .edge(30, 40),
                     parent: 10,
                     children: [20])

        let refs = frame.brokenReferences()
        
        #expect(refs.count == 4)
        #expect(refs.contains(10))
        #expect(refs.contains(20))
        #expect(refs.contains(30))
        #expect(refs.contains(40))
    }
    
    @Test func rejectBrokenEdgeEndpoint() throws {
        frame.create(TestEdgeType, id: 10, structure: .edge(900, 901))

        #expect(frame.brokenReferences().count == 2)
        #expect(frame.brokenReferences().contains(ObjectID(900)))
        #expect(frame.brokenReferences().contains(ObjectID(901)))
        #expect(throws: StructuralIntegrityError.brokenStructureReference) {
            try frame.validateStructure()
        }

    }

    @Test func rejectMissingParent() throws {
        frame.create(TestType, id: 20, parent: 902)

        #expect(frame.brokenReferences().count == 1)
        #expect(frame.brokenReferences().contains(ObjectID(902)))
        #expect(throws: StructuralIntegrityError.brokenParent) {
            try frame.validateStructure()
        }
    }

    @Test func rejectMissingChild() throws {
        frame.create(TestType, id: 20, children: [903])

        #expect(frame.brokenReferences().count == 1)
        #expect(frame.brokenReferences().contains(903))
        #expect(throws: StructuralIntegrityError.brokenChild) {
            try frame.validateStructure()
        }
    }

    @Test func rejectBrokenParentChild() throws {
        frame.create(TestType, id: 10, children: [20])
        frame.create(TestType, id: 20, parent: 30)
        frame.create(TestType, id: 30)

        #expect {
            try frame.validateStructure()
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .parentChildMismatch
        }
    }
    
    @Test func rejectBrokenParentNoChild() throws {
        frame.create(TestType, id: 10, parent: 30)
        frame.create(TestType, id: 30)

        #expect {
            try frame.validateStructure()
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .parentChildMismatch
        }
    }

    @Test func rejectBrokenParentChildCycle() throws {
        frame.create(TestType, id: 10, parent: 30, children: [30])
        frame.create(TestType, id: 30, parent: 10, children: [10])

        #expect{
            try frame.validateStructure()
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .parentChildCycle
        }

    }
    
    @Test func rejectEdgeEndpointNotANode() throws {
        frame.create(TestEdgeType, id: 10, structure: .edge(20, 20))
        frame.create(TestType, id: 20)

        #expect {
            try frame.validateStructure()
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .edgeEndpointNotANode
        }
    }
}
