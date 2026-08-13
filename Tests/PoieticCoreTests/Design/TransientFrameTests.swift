//
//  TransientFrameTests.swift
//  
//
//  Created by Stefan Urbanek on 04/09/2023.
//

import Testing
@testable import PoieticCore

// TODO: [IMPORTANT] Test reservation release on transient plane

@Suite struct TransientFrameTest {
    let design: Design
    let plane: TransientPlane
    
    init() throws {
        design = Design(metamodel: TestMetamodel)
        plane = design.createPlane()
    }
   
    @Test func create() throws {
        let a = plane.create(TestType)
        let b = plane.create(TestType)
        
        #expect(plane.contains(a.objectID))
        #expect(plane.contains(b.objectID))
        #expect(plane.hasChanges)
    }

    @Test func defaultValueTrait() {
        let a = plane.create(TestTypeNoDefault)
        #expect(a["text"] == nil)

        let b = plane.create(TestTypeWithDefault)
        #expect(b["text"] == "default")
    }
    
    @Test func defaultValueTraitError() throws {
        // FIXME: Move to constraint checker tests
        let a = plane.create(TestTypeNoDefault)
        let b = plane.create(TestTypeWithDefault)

        let checker = ConstraintChecker(plane.design.metamodel)
        let result = checker.diagnose(plane)
        let objErrors = try #require(result.objectErrors[a.objectID])
        #expect(result.violations.count == 0)
        #expect(result.objectErrors.count == 1)
        #expect(objErrors.first == ObjectTypeError.missingTraitAttribute(TestTraitNoDefault.attributes[0], "Test"))
        #expect(result.objectErrors[b.objectID] == nil)
    }

    @Test func derivedStructureIsPreserved() throws {
        let original = plane.create(TestNodeType, topology: .node)
        let originalPlane = try design.accept(plane)
        
        let derivedPlane = design.createPlane(deriving: originalPlane)
        let derived = derivedPlane.mutate(original.objectID)

        #expect(original.topology == derived.topology)
    }

    // MARK: Basics
    
    @Test func setAttribute() throws {
        let obj = plane.create(TestType, attributes: ["text": Variant("before")])
        
        obj.setAttribute(value: Variant("after"), forKey: "text")
        
        let value = obj["text"]
        #expect(try value?.stringValue() == "after")
        #expect(obj["text"] == "after")
    }
    
    // Mutate
    
    @Test func mutateBasicBehavior() throws {
        let obj = plane.create(TestType)
        let originalSnap = try #require(plane[obj.objectID])
        try design.accept(plane)
        
        let derived = design.createPlane(deriving: design.currentPlane!)
        let derivedSnap = derived.mutate(obj.objectID)
        
        #expect(derivedSnap.objectID == originalSnap.objectID)
        #expect(derivedSnap.snapshotID != originalSnap.snapshotID)
        
        let derivedSnap2 = derived.mutate(obj.objectID)
        #expect(derivedSnap === derivedSnap2)
    }

    @Test func mutatePreservesAttributes() throws {
        let obj = plane.create(TestType, attributes: ["text": "hello"])
        try design.accept(plane)
        
        let derived = design.createPlane(deriving: design.currentPlane!)
        let derivedSnap = derived.mutate(obj.objectID)
        
        #expect(derivedSnap["text"] == "hello")
    }
    

    @Test func originalValuePreservedOnMutate() throws {
        let object = plane.create(TestType, attributes: ["text": Variant("before")])
        let original = try design.accept(plane)
        
        let plane2 = design.createPlane(deriving: original)
        let changedObject = plane2.mutate(object.objectID)
        changedObject["text"] = "after"
        
        #expect(plane2.hasChanges)

        let changedPlane = try design.accept(plane2)
        let changedObject2 = try #require(changedPlane[object.objectID])
        
        #expect(changedObject2["text"] == "after")
        
        let originalObject = try #require(design.plane(original.id)![object.objectID])
        #expect(originalObject["text"] == "before")
    }
    

    @Test func removeObjectCascading() throws {
        let node1 = plane.create(TestNodeType)
        let node2 = plane.create(TestNodeType)
        let edge = plane.create(TestEdgeType, topology: .edge(node1.objectID, node2.objectID))
        
        let removed = plane.removeCascading(node1.objectID)
        #expect(removed.count == 2)
        #expect(removed.contains(edge.objectID))
        #expect(removed.contains(node1.objectID))

        #expect(!plane.contains(node1.objectID))
        #expect(!plane.contains(edge.objectID))
        #expect(plane.contains(node2.objectID))
    }

    @Test func onlyOriginalsRemoved() throws {
        let originalNode = plane.create(TestNodeType, topology: .node)
        let original = try design.accept(plane)
        
        let trans = design.createPlane(deriving: original)
        #expect(trans.contains(snapshotID: originalNode.snapshotID))
        trans.removeCascading(originalNode.objectID)
        #expect(trans.snapshots.isEmpty)
        #expect(!trans.contains(snapshotID: originalNode.snapshotID))

        let newNode = trans.create(TestNodeType)

        #expect(trans.removedObjects.count == 1)
        #expect(!trans.removedObjects.contains(newNode.objectID))
        #expect(trans.removedObjects.contains(originalNode.objectID))

        #expect(!trans.contains(originalNode.objectID))
        #expect(trans.contains(newNode.objectID))
    }

    @Test func replaceObject() throws {
        let originalNode = plane.create(TestNodeType, topology: .node)
        let original = try design.accept(plane)

        let trans = design.createPlane(deriving: original)

        trans.removeCascading(originalNode.objectID)
        #expect(trans.removedObjects.count == 1)
        #expect(trans.removedObjects.contains(originalNode.objectID))

        let newNode = trans.create(TestNodeType, objectID: originalNode.objectID)

        #expect(trans.contains(snapshotID: newNode.snapshotID))
        #expect(trans.removedObjects.count == 0)
        #expect(trans.contains(newNode.objectID))
    }

    @Test func mutableObjectRemovesPreviousSnapshot() throws {
        let original = design.createPlane()
        let originalSnap = original.create(TestType)
        try design.accept(original)
        
        let derived = design.createPlane(deriving: design.currentPlane!)

        #expect(derived.contains(snapshotID: originalSnap.snapshotID))

        let derivedSnap = derived.mutate(originalSnap.objectID)
        #expect(derived.snapshots.count == 1)

        #expect(!derived.snapshots.contains(where: { $0.snapshotID == originalSnap.snapshotID }))
        #expect(derived.snapshots.contains(where: { $0.snapshotID == derivedSnap.snapshotID }))
        #expect(!derived.contains(snapshotID: originalSnap.snapshotID))
        #expect(derived.contains(snapshotID: derivedSnap.snapshotID))
    }

    // MARK: Parent-child
    
    @Test func addChild() throws {
        let a = plane.create(TestType)
        let b = plane.create(TestType)
        let c = plane.create(TestType)
        
        plane.addChild(b.objectID, to: a.objectID)
        plane.addChild(c.objectID, to: a.objectID)
        
        #expect(a.children == [b.objectID, c.objectID])
        #expect(b.parent == a.objectID)
        #expect(c.parent == a.objectID)
    }
    

    @Test func removeChild() throws {
        let a = plane.create(TestType)
        let b = plane.create(TestType)
        let c = plane.create(TestType)
        
        plane.addChild(b.objectID, to: a.objectID)
        plane.addChild(c.objectID, to: a.objectID)
        
        plane.removeChild(c.objectID, from: a.objectID)
        
        #expect(a.children == [b.objectID])
        #expect(c.parent == nil)
        #expect(b.parent == a.objectID)
        #expect(c.parent == nil)
    }
    
    @Test func setParent() throws {
        let a = plane.create(TestType)
        let b = plane.create(TestType)
        let c = plane.create(TestType)
        
        plane.addChild(b.objectID, to: a.objectID)
        plane.setParent(c.objectID, to: a.objectID)
        
        #expect(a.children == [b.objectID, c.objectID])
        #expect(b.parent == a.objectID)
        #expect(c.parent == a.objectID)
        
        plane.setParent(c.objectID, to: b.objectID)
        
        #expect(a.children == [b.objectID])
        #expect(b.children == [c.objectID])
        #expect(b.parent == a.objectID)
        #expect(c.parent == b.objectID)
    }
    
    @Test func removeFromParent() throws {
        let a = plane.create(TestType)
        let b = plane.create(TestType)
        let c = plane.create(TestType)
        
        plane.addChild(b.objectID, to: a.objectID)
        plane.addChild(c.objectID, to: a.objectID)

        plane.removeFromParent(b.objectID)
        #expect(b.parent == nil)
        #expect(a.children == [c.objectID])

        plane.removeFromParent(c.objectID)
        #expect(c.parent == nil)
        #expect(a.children == [])
    }

    @Test func removeFromUnownedParentMutates() throws {
        let p = plane.create(TestType)
        let c1 = plane.create(TestType)
        let c2 = plane.create(TestType)
        
        plane.addChild(c1.objectID, to: p.objectID)
        plane.addChild(c2.objectID, to: p.objectID)

        let accepted = try design.accept(plane)
        let derived = design.createPlane(deriving: accepted)
        derived.removeFromParent(c1.objectID)

        let derivedP = try #require(derived[p.objectID])
        #expect(derivedP.snapshotID != p.snapshotID)
    }
    
    @Test func removeCascadingChildren() throws {
        // a - b - c
        // d - e - f
        //
        let a = plane.create(TestType)
        let b = plane.create(TestType)
        let c = plane.create(TestType)
        let d = plane.create(TestType)
        let e = plane.create(TestType)
        let f = plane.create(TestType)

        plane.addChild(b.objectID, to: a.objectID)
        plane.addChild(c.objectID, to: b.objectID)
        plane.addChild(e.objectID, to: d.objectID)
        plane.addChild(f.objectID, to: e.objectID)

        plane.removeCascading(b.objectID)
        #expect(!plane.contains(b.objectID))
        #expect(!plane.contains(c.objectID))
        #expect(!plane[a.objectID]!.children.contains(b.objectID))

        plane.removeCascading(d.objectID)
        #expect(!plane.contains(d.objectID))
        #expect(!plane.contains(e.objectID))
        #expect(!plane.contains(f.objectID))
    }
    
    @Test func deriveObjectPreservesParentChild() throws {
        let obj = plane.create(TestNodeType, topology: .node)
        let parent = plane.create(TestNodeType, topology: .node)
        let child = plane.create(TestNodeType, topology: .node)
        plane.setParent(obj.objectID, to: parent.objectID)
        plane.setParent(child.objectID, to: obj.objectID)
        
        let derivedPlane = design.createPlane(deriving: try design.accept(plane))
        let derivedObj = derivedPlane.mutate(obj.objectID)

        #expect(derivedObj.parent == parent.objectID)
        #expect(derivedObj.children == [child.objectID])

        let derivedParent = derivedPlane.mutate(parent.objectID)
        #expect(derivedParent.parent == nil)
        #expect(derivedParent.children == [obj.objectID])

        let derivedChild = derivedPlane.mutate(child.objectID)
        #expect(derivedChild.parent == obj.objectID)
        #expect(derivedChild.children == [])
    }
    
    @Test func parentChildIsPreservedOnAccept() throws {
        let obj = plane.create(TestNodeType, topology: .node)
        let parent = plane.create(TestNodeType, topology: .node)
        let child = plane.create(TestNodeType, topology: .node)

        plane.setParent(obj.objectID, to: parent.objectID)
        plane.setParent(child.objectID, to: obj.objectID)
        
        let accepted = try design.accept(plane)
        let accObj = try #require(accepted[obj.objectID])
        
        #expect(accObj.children == obj.children)
        #expect(accObj.parent == obj.parent)
    }

    // MARK: References and Referential Integrity
    
    @Test func brokenReferences() throws {
        let object = plane.create(TestEdgeType,
                                  objectID: 5,
                                  topology: .edge(30, 40),
                                  parent: 10,
                                  children: [20])

        let refs = StructuralValidator.brokenReferences(object,in: plane)
        
        #expect(refs.count == 4)
        #expect(refs.contains(10))
        #expect(refs.contains(20))
        #expect(refs.contains(30))
        #expect(refs.contains(40))
    }
    
    @Test func rejectBrokenEdgeEndpoint() throws {
        let object = plane.create(TestEdgeType, objectID: 10, topology: .edge(900, 901))
        let refs = StructuralValidator.brokenReferences(object, in: plane)
        #expect(refs.count == 2)
        #expect(refs.contains(ObjectID(900)))
        #expect(refs.contains(ObjectID(901)))
        #expect(throws: StructuralIntegrityError.brokenStructureReference) {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        }

    }

    @Test func rejectMissingParent() throws {
        let object = plane.create(TestType, objectID: 20, parent: 902)
        let refs = StructuralValidator.brokenReferences(object, in: plane)

        #expect(refs.count == 1)
        #expect(refs.contains(ObjectID(902)))
        #expect(throws: StructuralIntegrityError.brokenParent) {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        }
    }

    @Test func rejectMissingChild() throws {
        let object = plane.create(TestType, objectID: 20, children: [903])
        let refs = StructuralValidator.brokenReferences(object, in: plane)

        #expect(refs.count == 1)
        #expect(refs.contains(903))
        #expect(throws: StructuralIntegrityError.brokenChild) {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        }
    }

    @Test func rejectBrokenParentChild() throws {
        plane.create(TestType, objectID: 10, children: [20])
        plane.create(TestType, objectID: 20, parent: 30)
        plane.create(TestType, objectID: 30)

        #expect {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .parentChildMismatch
        }
    }
    
    @Test func rejectBrokenParentNoChild() throws {
        plane.create(TestType, objectID: 10, parent: 30)
        plane.create(TestType, objectID: 30)

        #expect {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .parentChildMismatch
        }
    }

    @Test func rejectBrokenParentChildCycle() throws {
        plane.create(TestType, objectID: 10, parent: 30, children: [30])
        plane.create(TestType, objectID: 30, parent: 10, children: [10])

        #expect{
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .parentChildCycle
        }

    }
    
    @Test func rejectEdgeEndpointNotANode() throws {
        plane.create(TestEdgeType, objectID: 10, topology: .edge(20, 20))
        plane.create(TestType, objectID: 20)

        #expect {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        } throws: {
            guard let error = $0 as? StructuralIntegrityError else {
                return false
            }
            return error == .edgeEndpointNotANode
        }
    }
    
    @Test func reserveIdentities() throws {
        #expect(!design.identityManager.isReserved(ObjectID(10), type: .object))
        #expect(!design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
        plane.create(TestType, objectID: ObjectID(20), snapshotID: ObjectSnapshotID(10))
        #expect(design.identityManager.isReserved(ObjectSnapshotID(10), type: .objectSnapshot))
        #expect(design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
    }

    @Test func reserveAndAccept() throws {
        plane.create(TestType, objectID: ObjectID(20), snapshotID: ObjectSnapshotID(10))
        try design.accept(plane)
        #expect(!design.identityManager.isReserved(ObjectID(10), type: .object))
        #expect(!design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(ObjectID(20)))
    }

    @Test func reserveAndDiscard() throws {
        plane.create(TestType, objectID: ObjectID(20), snapshotID: ObjectSnapshotID(10))
        design.discard(plane)
        #expect(!design.identityManager.isReserved(ObjectID(10), type: .object))
        #expect(!design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
    }
}
