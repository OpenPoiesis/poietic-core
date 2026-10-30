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
        design = Design(metamodel: TestDomain.TestMetamodel)
        plane = design.createPlane()
    }
   
    @Test func create() throws {
        let a = plane.create(TestDomain.Types.TestUnstructured)
        let b = plane.create(TestDomain.Types.TestUnstructured)
        
        #expect(plane.contains(a.objectID))
        #expect(plane.contains(b.objectID))
        #expect(plane.hasChanges)
    }

    @Test func defaultValueTrait() {
        let a = plane.create(TestDomain.Types.NoDefaultText)
        #expect(a["text"] == nil)

        let b = plane.create(TestDomain.Types.DefaultText)
        #expect(b["text"] == "default")
    }
    
    @Test func defaultValueTraitError() throws {
        // FIXME: Move to constraint checker tests
        let a = plane.create(TestDomain.Types.NoDefaultText)
        let b = plane.create(TestDomain.Types.DefaultText)

        let checker = ConstraintChecker(plane.design.metamodel)
        let result = checker.diagnose(plane)
        let objErrors = try #require(result.objectErrors[a.objectID])
        #expect(result.violations.count == 0)
        #expect(result.objectErrors.count == 1)
        #expect(objErrors.first == ObjectTypeError.missingTraitAttribute(
            TestDomain.Traits.NoDefaultText.attributes[0], "NoDefaultText")
        )
        #expect(result.objectErrors[b.objectID] == nil)
    }

    @Test func derivedStructureIsPreserved() throws {
        let original = plane.create(TestDomain.Types.TestNode, topology: .node)
        let originalPlane = try design.accept(plane)
        
        let derivedPlane = design.createPlane(deriving: originalPlane)
        let derived = derivedPlane.mutate(original.objectID)

        #expect(original.topology == derived.topology)
    }

    // MARK: Basics
    
    @Test func setAttribute() throws {
        let obj = plane.create(TestDomain.Types.TestUnstructured, attributes: ["text": Variant("before")])
        
        obj.setAttribute(value: Variant("after"), forKey: "text")
        
        let value = obj["text"]
        #expect(try value?.stringValue() == "after")
        #expect(obj["text"] == "after")
    }
    
    // Mutate
    
    @Test func mutateBasicBehavior() throws {
        let obj = plane.create(TestDomain.Types.TestUnstructured)
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
        let obj = plane.create(TestDomain.Types.TestUnstructured, attributes: ["text": "hello"])
        try design.accept(plane)
        
        let derived = design.createPlane(deriving: design.currentPlane!)
        let derivedSnap = derived.mutate(obj.objectID)
        
        #expect(derivedSnap["text"] == "hello")
    }
    

    @Test func originalValuePreservedOnMutate() throws {
        let object = plane.create(TestDomain.Types.TestUnstructured, attributes: ["text": Variant("before")])
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
        let node1 = plane.create(TestDomain.Types.TestNode)
        let node2 = plane.create(TestDomain.Types.TestNode)
        let edge = plane.create(TestDomain.Types.TestEdge, topology: .edge(node1.objectID, node2.objectID))
        
        let removed = plane.removeCascading(node1.objectID)
        #expect(removed.count == 2)
        #expect(removed.contains(edge.objectID))
        #expect(removed.contains(node1.objectID))

        #expect(!plane.contains(node1.objectID))
        #expect(!plane.contains(edge.objectID))
        #expect(plane.contains(node2.objectID))
    }

    @Test func onlyOriginalsRemoved() throws {
        let originalNode = plane.create(TestDomain.Types.TestNode, topology: .node)
        let original = try design.accept(plane)
        
        let trans = design.createPlane(deriving: original)
        #expect(trans.contains(snapshotID: originalNode.snapshotID))
        trans.removeCascading(originalNode.objectID)
        #expect(trans.snapshots.isEmpty)
        #expect(!trans.contains(snapshotID: originalNode.snapshotID))

        let newNode = trans.create(TestDomain.Types.TestNode)

        #expect(trans.removedObjects.count == 1)
        #expect(!trans.removedObjects.contains(newNode.objectID))
        #expect(trans.removedObjects.contains(originalNode.objectID))

        #expect(!trans.contains(originalNode.objectID))
        #expect(trans.contains(newNode.objectID))
    }

    @Test func replaceObject() throws {
        let originalNode = plane.create(TestDomain.Types.TestNode, topology: .node)
        let original = try design.accept(plane)

        let trans = design.createPlane(deriving: original)

        trans.removeCascading(originalNode.objectID)
        #expect(trans.removedObjects.count == 1)
        #expect(trans.removedObjects.contains(originalNode.objectID))

        let newNode = trans.create(TestDomain.Types.TestNode, objectID: originalNode.objectID)

        #expect(trans.contains(snapshotID: newNode.snapshotID))
        #expect(trans.removedObjects.count == 0)
        #expect(trans.contains(newNode.objectID))
    }

    @Test func mutableObjectRemovesPreviousSnapshot() throws {
        let original = design.createPlane()
        let originalSnap = original.create(TestDomain.Types.TestUnstructured)
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

    // MARK: References and Referential Integrity
    
    @Test func brokenReferences() throws {
        let object = plane.create(TestDomain.Types.TestEdge,
                                  objectID: 5,
                                  topology: .edge(30, 40))

        let refs = StructuralValidator.brokenReferences(object,in: plane)
        
        #expect(refs.count == 2)
        #expect(refs.contains(30))
        #expect(refs.contains(40))
    }
    
    @Test func rejectBrokenEdgeEndpoint() throws {
        let object = plane.create(TestDomain.Types.TestEdge, objectID: 10, topology: .edge(900, 901))
        let refs = StructuralValidator.brokenReferences(object, in: plane)
        #expect(refs.count == 2)
        #expect(refs.contains(ObjectID(900)))
        #expect(refs.contains(ObjectID(901)))
        #expect(throws: StructuralIntegrityError.brokenStructureReference) {
            try StructuralValidator.validate(snapshots: plane.snapshots, in: plane)
        }

    }

    @Test func rejectEdgeEndpointNotANode() throws {
        plane.create(TestDomain.Types.TestEdge, objectID: 10, topology: .edge(20, 20))
        plane.create(TestDomain.Types.TestUnstructured, objectID: 20)

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
        plane.create(TestDomain.Types.TestUnstructured, objectID: ObjectID(20), snapshotID: ObjectSnapshotID(10))
        #expect(design.identityManager.isReserved(ObjectSnapshotID(10), type: .objectSnapshot))
        #expect(design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
    }

    @Test func reserveAndAccept() throws {
        plane.create(TestDomain.Types.TestUnstructured, objectID: ObjectID(20), snapshotID: ObjectSnapshotID(10))
        try design.accept(plane)
        #expect(!design.identityManager.isReserved(ObjectID(10), type: .object))
        #expect(!design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(design.identityManager.isUsed(ObjectID(10)))
        #expect(design.identityManager.isUsed(ObjectID(20)))
    }

    @Test func reserveAndDiscard() throws {
        plane.create(TestDomain.Types.TestUnstructured, objectID: ObjectID(20), snapshotID: ObjectSnapshotID(10))
        design.discard(plane)
        #expect(!design.identityManager.isReserved(ObjectID(10), type: .object))
        #expect(!design.identityManager.isReserved(ObjectID(20), type: .object))
        #expect(!design.identityManager.isUsed(ObjectID(10)))
        #expect(!design.identityManager.isUsed(ObjectID(20)))
    }
}
