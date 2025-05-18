//
//  TransientFrameTests.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Testing
@testable import PoieticCore

// TODO: [WIP] Test reservation release on transient frame

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
        
        #expect(frame.contains(a.objectID))
        #expect(frame.contains(b.objectID))
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
            guard let objErrors = error.objectErrors[a.objectID] else {
                Issue.record("Expected errors for object 'a'")
                return false
            }
            

            return error.violations.count == 0
                    && error.objectErrors.count == 1
                    && objErrors.first == .missingTraitAttribute(TestTraitNoDefault.attributes[0], "Test")
                    && error.objectErrors[b.objectID] == nil
        }
    }

    @Test func derivedStructureIsPreserved() throws {
        let original = frame.create(TestNodeType)
        let originalFrame = try design.accept(frame)
        
        let derivedFrame = design.createFrame(deriving: originalFrame)
        let derived = derivedFrame.mutate(original.objectID)

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
        let originalSnap = frame[obj.objectID]
        try design.accept(frame)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(obj.objectID)
        
        #expect(derivedSnap.objectID == originalSnap.objectID)
        #expect(derivedSnap.snapshotID != originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutate(obj.objectID)
        #expect(derivedSnap === derivedSnap2)
    }

    @Test func mutatePreservesAttributes() throws {
        let obj = frame.create(TestType, attributes: ["text": "hello"])
        try design.accept(frame)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(obj.objectID)
        
        #expect(derivedSnap["text"] == "hello")
    }
    

    @Test func originalValuePreservedOnMutate() throws {
        let object = frame.create(TestType, attributes: ["text": Variant("before")])
        let original = try design.accept(frame)
        
        let frame2 = design.createFrame(deriving: original)
        let changedObject = frame2.mutate(object.objectID)
        changedObject["text"] = "after"
        
        #expect(frame2.hasChanges)

        let changedFrame = try design.accept(frame2)
        
        #expect(changedFrame[object.objectID]["text"] == "after")
        
        let originalObject = design.frame(original.id)![object.objectID]
        #expect(originalObject["text"] == "before")
    }
    

    @Test func originalComponentPreservedOnMutate() throws {
        let object = frame.create(TestType, components: [TestComponent(text: "before")])
        let original = try design.accept(frame)
        
        let frame2 = design.createFrame(deriving: original)
        let changedObject = frame2.mutate(object.objectID)
        changedObject[TestComponent.self] = TestComponent(text: "after")
        
        #expect(frame2.hasChanges)

        let changedFrame = try design.accept(frame2)
        let comp: TestComponent = changedFrame[object.objectID][TestComponent.self]!
        #expect(comp.text == "after")
        
        let originalObject = design.frame(original.id)![object.objectID]
        let compOrignal: TestComponent = originalObject[TestComponent.self]!
        #expect(compOrignal.text == "before")
    }
    
    @Test func removeObjectCascading() throws {
        let node1 = frame.create(TestNodeType)
        let node2 = frame.create(TestNodeType)
        let edge = frame.create(TestEdgeType, structure: .edge(node1.objectID, node2.objectID))
        
        let removed = frame.removeCascading(node1.objectID)
        #expect(removed.count == 2)
        #expect(removed.contains(edge.objectID))
        #expect(removed.contains(node1.objectID))

        #expect(!frame.contains(node1.objectID))
        #expect(!frame.contains(edge.objectID))
        #expect(frame.contains(node2.objectID))
    }

    @Test func onlyOriginalsRemoved() throws {
        let originalNode = frame.create(TestNodeType)
        let original = try design.accept(frame)
        
        let trans = design.createFrame(deriving: original)
        #expect(trans.contains(snapshotID: originalNode.snapshotID))
        trans.removeCascading(originalNode.objectID)
        #expect(!trans.contains(snapshotID: originalNode.snapshotID))

        let newNode = trans.create(TestNodeType)

        #expect(trans.removedObjects.count == 1)
        #expect(!trans.removedObjects.contains(newNode.objectID))
        #expect(trans.removedObjects.contains(originalNode.objectID))

        #expect(!trans.contains(originalNode.objectID))
        #expect(trans.contains(newNode.objectID))
    }

    @Test func replaceObject() throws {
        let originalNode = frame.create(TestNodeType)
        let original = try design.accept(frame)

        let trans = design.createFrame(deriving: original)

        trans.removeCascading(originalNode.objectID)
        #expect(trans.removedObjects.count == 1)
        #expect(trans.removedObjects.contains(originalNode.objectID))

        let newNode = trans.create(TestNodeType, objectID: originalNode.objectID)

        #expect(trans.contains(snapshotID: newNode.snapshotID))
        #expect(trans.removedObjects.count == 0)
        #expect(trans.contains(newNode.objectID))
    }

    @Test func mutableObjectRemovesPreviousSnapshot() throws {
        let original = design.createFrame()
        let originalSnap = original.create(TestType)
        try design.accept(original)
        
        let derived = design.createFrame(deriving: design.currentFrame)
        let derivedSnap = derived.mutate(originalSnap.objectID)
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
        
        frame.addChild(b.objectID, to: a.objectID)
        frame.addChild(c.objectID, to: a.objectID)
        
        #expect(a.children == [b.objectID, c.objectID])
        #expect(b.parent == a.objectID)
        #expect(c.parent == a.objectID)
    }
    

    @Test func removeChild() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.objectID, to: a.objectID)
        frame.addChild(c.objectID, to: a.objectID)
        
        frame.removeChild(c.objectID, from: a.objectID)
        
        #expect(a.children == [b.objectID])
        #expect(c.parent == nil)
        #expect(b.parent == a.objectID)
        #expect(c.parent == nil)
    }
    
    @Test func setParent() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.objectID, to: a.objectID)
        frame.setParent(c.objectID, to: a.objectID)
        
        #expect(a.children == [b.objectID, c.objectID])
        #expect(b.parent == a.objectID)
        #expect(c.parent == a.objectID)
        
        frame.setParent(c.objectID, to: b.objectID)
        
        #expect(a.children == [b.objectID])
        #expect(b.children == [c.objectID])
        #expect(b.parent == a.objectID)
        #expect(c.parent == b.objectID)
    }
    
    @Test func removeFromParent() throws {
        let a = frame.create(TestType)
        let b = frame.create(TestType)
        let c = frame.create(TestType)
        
        frame.addChild(b.objectID, to: a.objectID)
        frame.addChild(c.objectID, to: a.objectID)

        frame.removeFromParent(b.objectID)
        #expect(b.parent == nil)
        #expect(a.children == [c.objectID])

        frame.removeFromParent(c.objectID)
        #expect(c.parent == nil)
        #expect(a.children == [])
    }

    @Test func removeFromUnownedParentMutates() throws {
        let p = frame.create(TestType)
        let c1 = frame.create(TestType)
        let c2 = frame.create(TestType)
        
        frame.addChild(c1.objectID, to: p.objectID)
        frame.addChild(c2.objectID, to: p.objectID)

        let accepted = try design.accept(frame)
        let derived = design.createFrame(deriving: accepted)
        derived.removeFromParent(c1.objectID)

        let derivedP = derived[p.objectID]
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

        frame.addChild(b.objectID, to: a.objectID)
        frame.addChild(c.objectID, to: b.objectID)
        frame.addChild(e.objectID, to: d.objectID)
        frame.addChild(f.objectID, to: e.objectID)

        frame.removeCascading(b.objectID)
        #expect(!frame.contains(b.objectID))
        #expect(!frame.contains(c.objectID))
        #expect(!frame[a.objectID].children.contains(b.objectID))

        frame.removeCascading(d.objectID)
        #expect(!frame.contains(d.objectID))
        #expect(!frame.contains(e.objectID))
        #expect(!frame.contains(f.objectID))
    }
    
    @Test func deriveObjectPreservesParentChild() throws {
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)
        frame.setParent(obj.objectID, to: parent.objectID)
        frame.setParent(child.objectID, to: obj.objectID)
        
        let derivedFrame = design.createFrame(deriving: try design.accept(frame))
        let derivedObj = derivedFrame.mutate(obj.objectID)

        #expect(derivedObj.parent == parent.objectID)
        #expect(derivedObj.children == [child.objectID])

        let derivedParent = derivedFrame.mutate(parent.objectID)
        #expect(derivedParent.parent == nil)
        #expect(derivedParent.children == [obj.objectID])

        let derivedChild = derivedFrame.mutate(child.objectID)
        #expect(derivedChild.parent == obj.objectID)
        #expect(derivedChild.children == [])
    }
    
    @Test func parentChildIsPreservedOnAccept() throws {
        let obj = frame.create(TestNodeType)
        let parent = frame.create(TestNodeType)
        let child = frame.create(TestNodeType)

        frame.setParent(obj.objectID, to: parent.objectID)
        frame.setParent(child.objectID, to: obj.objectID)
        
        let accepted = try design.accept(frame)

        #expect(accepted[obj.objectID].children == obj.children)
        #expect(accepted[obj.objectID].parent == obj.parent)
    }

    // MARK: References and Referential Integrity
    
    @Test func brokenReferences() throws {
        frame.create(TestEdgeType,
                     objectID: 5,
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
        frame.create(TestEdgeType, objectID: 10, structure: .edge(900, 901))

        #expect(frame.brokenReferences().count == 2)
        #expect(frame.brokenReferences().contains(ObjectID(900)))
        #expect(frame.brokenReferences().contains(ObjectID(901)))
        #expect(throws: StructuralIntegrityError.brokenStructureReference) {
            try frame.validateStructure()
        }

    }

    @Test func rejectMissingParent() throws {
        frame.create(TestType, objectID: 20, parent: 902)

        #expect(frame.brokenReferences().count == 1)
        #expect(frame.brokenReferences().contains(ObjectID(902)))
        #expect(throws: StructuralIntegrityError.brokenParent) {
            try frame.validateStructure()
        }
    }

    @Test func rejectMissingChild() throws {
        frame.create(TestType, objectID: 20, children: [903])

        #expect(frame.brokenReferences().count == 1)
        #expect(frame.brokenReferences().contains(903))
        #expect(throws: StructuralIntegrityError.brokenChild) {
            try frame.validateStructure()
        }
    }

    @Test func rejectBrokenParentChild() throws {
        frame.create(TestType, objectID: 10, children: [20])
        frame.create(TestType, objectID: 20, parent: 30)
        frame.create(TestType, objectID: 30)

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
        frame.create(TestType, objectID: 10, parent: 30)
        frame.create(TestType, objectID: 30)

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
        frame.create(TestType, objectID: 10, parent: 30, children: [30])
        frame.create(TestType, objectID: 30, parent: 10, children: [10])

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
        frame.create(TestEdgeType, objectID: 10, structure: .edge(20, 20))
        frame.create(TestType, objectID: 20)

        #expect {
            try frame.validateStructure()
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .edgeEndpointNotANode
        }
    }
    
    @Test func reserveIdentities() throws {
        #expect(!design.identityManager.isReserved(ObjectID(10)))
        #expect(!design.identityManager.isReserved(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
        frame.create(TestType, objectID: ObjectID(20), snapshotID: ObjectID(10))
        #expect(design.identityManager.isReserved(ObjectID(10)))
        #expect(design.identityManager.isReserved(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
    }

    @Test func reserveAndAccept() throws {
        frame.create(TestType, objectID: ObjectID(20), snapshotID: ObjectID(10))
        frame.accept()
        #expect(!design.identityManager.isReserved(ObjectID(10)))
        #expect(!design.identityManager.isReserved(ObjectID(20)))
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(ObjectID(20)))
    }

    @Test func reserveAndDiscard() throws {
        frame.create(TestType, objectID: ObjectID(20), snapshotID: ObjectID(10))
        frame.discard()
        #expect(!design.identityManager.isReserved(ObjectID(10)))
        #expect(!design.identityManager.isReserved(ObjectID(20)))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
    }
}
