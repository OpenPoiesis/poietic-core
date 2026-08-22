//
//  WorldFrameChangeTests.swift
//  poietic-core
//
//  Tests for World.setPlane(_:) behaviour — entity lifecycle across plane changes,
//  relationship cascading, and ObjectID→RuntimeID mapping.
//
import Testing
@testable import PoieticCore

@Suite struct WorldFrameChangeTests {
    // MARK: - Fixture Frames

    let design: Design
    let emptyFrame: DesignPlane
    /// Plane with two node objects: first → Stock("A"), second → FlowRate("B").
    let frameWithTwo: DesignPlane
    let firstObjectID: ObjectID
    let secondObjectID: ObjectID
    /// Plane derived from `frameWithTwo` where the first object was mutated
    /// (text changed from "A" → "Changed"). Same ObjectIDs, different snapshots.
    let frameWithMutation: DesignPlane
    /// Plane derived from `frameWithTwo` where the second object was removed.
    let frameWithRemoval: DesignPlane

    init() throws {
        self.design = Design(metamodel: TestMetamodel)

        // --- emptyFrame ---
        let t0 = design.createPlane()
        self.emptyFrame = try design.accept(t0)

        // --- frameWithTwo ---
        let t1 = design.createPlane()
        let obj1 = t1.create(.Stock, topology: .node, attributes: ["text": "A"])
        let obj2 = t1.create(.FlowRate, topology: .node, attributes: ["text": "B"])
        self.firstObjectID = obj1.objectID
        self.secondObjectID = obj2.objectID
        self.frameWithTwo = try design.accept(t1)

        // --- frameWithMutation: first object text changed ---
        let t2 = design.createPlane(deriving: frameWithTwo)
        let mutated = t2.mutate(firstObjectID)
        mutated["text"] = "Changed"
        self.frameWithMutation = try design.accept(t2)

        // --- frameWithRemoval: second object removed ---
        let t3 = design.createPlane(deriving: frameWithTwo)
        t3.removeCascading(secondObjectID)
        self.frameWithRemoval = try design.accept(t3)
    }

    // MARK: - Survival of non-plane entities

    @Test func setEmptyToEmptyPreservesNonFrameEntities() throws {
        let world = World(plane: emptyFrame)
        let survivor = world.spawn(TestComponent(text: "alive"))

        world.setPlane(emptyFrame)

        #expect(world.contains(survivor))
    }

    @Test func setContentToEmptyPreservesNonFrameEntities() throws {
        let world = World(plane: frameWithTwo)
        #expect(world.entities.count == 2)

        let survivor = world.spawn(TestComponent(text: "i-survive"))

        world.setPlane(emptyFrame)

        #expect(world.objectToEntity(firstObjectID) == nil)
        #expect(world.objectToEntity(secondObjectID) == nil)
        #expect(world.contains(survivor))
    }

    @Test func nonFrameEntitySurvivesAll() throws {
        let world = World(plane: emptyFrame)
        let survivor = world.spawn(TestComponent(text: "persistent"))

        // empty → content
        world.setPlane(frameWithTwo)
        #expect(world.contains(survivor))

        // content → mutated
        world.setPlane(frameWithMutation)
        #expect(world.contains(survivor))

        // mutated → removed
        world.setPlane(frameWithRemoval)
        #expect(world.contains(survivor))

        // removed → empty
        world.setPlane(emptyFrame)
        #expect(world.contains(survivor))
    }

    @Test func nonFrameEntitiesNeverGetObjectTouched() throws {
        let world = World(plane: frameWithTwo)
        let survivor: RuntimeEntity = world.spawn()

        world.setPlane(frameWithMutation)
        #expect(!survivor.contains(ObjectTouched.self))
    }

    // MARK: - ObjectID to RuntimeID mapping

    @Test func newEntities() throws {
        let world = World(plane: emptyFrame)
        #expect(world.entities.count == 0)

        world.setPlane(frameWithTwo)
        #expect(world.entities.count == 2)

        let e1 = try #require(world.entity(firstObjectID))
        let e2 = try #require(world.entity(secondObjectID))

        #expect(e1.objectID == firstObjectID)
        #expect(e2.objectID == secondObjectID)

        #expect(e1.contains(ObjectTouched.self))
        #expect(e2.contains(ObjectTouched.self))

        let snap1: ObjectReference = try #require(e1.component())
        let snap2: ObjectReference = try #require(e2.component())
        
        #expect(snap1.snapshotID == frameWithTwo[firstObjectID]?.snapshotID)
        #expect(snap2.snapshotID == frameWithTwo[secondObjectID]?.snapshotID)
    }

    @Test func sameFramePreservesEntities() throws {
        let world = World(plane: frameWithTwo)

        let e1Before = try #require(world.entity(firstObjectID))
        let e2Before = try #require(world.entity(secondObjectID))

        world.setPlane(frameWithTwo)  // same plane again
        let e1After = try #require(world.entity(firstObjectID))
        let e2After = try #require(world.entity(secondObjectID))

        #expect(e1Before.runtimeID == e1After.runtimeID)
        #expect(e2Before.runtimeID == e2After.runtimeID)

        // clear touch flag
        #expect(!e1After.contains(ObjectTouched.self))
        #expect(!e2After.contains(ObjectTouched.self))
    }

    // MARK: - Removal

    @Test func removedObjectEntityIsDespawned() throws {
        let world = World(plane: frameWithTwo)
        let e1 = try #require(world.entity(firstObjectID))
        let e2 = try #require(world.entity(secondObjectID))

        #expect(world.entity(firstObjectID) != nil)
        #expect(world.entity(secondObjectID) != nil)

        world.setPlane(frameWithRemoval)
        #expect(world.entity(firstObjectID) != nil)
        #expect(world.entity(secondObjectID) == nil)
        #expect(world.contains(e1.runtimeID))
        #expect(!world.contains(e2.runtimeID))
    }

    // MARK: - Mutation

    @Test func mutationPreservesEntities() throws {
        let world = World(plane: frameWithTwo)
        let changed = try #require(world.entity(firstObjectID))
        let unchanged = try #require(world.entity(secondObjectID))

        world.setPlane(frameWithMutation)

        #expect(world.contains(changed.runtimeID))
        #expect(world.contains(unchanged.runtimeID))
        
        #expect(changed.objectID == firstObjectID)
        #expect(unchanged.objectID == secondObjectID)
    }
    
    @Test func mutationTouchesChanged() throws {
        let world = World(plane: frameWithTwo)
        let changed = try #require(world.entity(firstObjectID))
        let unchanged = try #require(world.entity(secondObjectID))

        world.setPlane(frameWithMutation)

        #expect(changed.contains(ObjectTouched.self))
        #expect(!unchanged.contains(ObjectTouched.self))
    }

    @Test func mutationIdentityBehaviour() throws {
        let world = World(plane: frameWithTwo)
        let changed = try #require(world.entity(firstObjectID))
        let unchanged = try #require(world.entity(secondObjectID))

        let changedSnapBefore: ObjectReference = try #require(changed.component())
        let unchangedSnapBefore: ObjectReference = try #require(unchanged.component())

        world.setPlane(frameWithMutation)

        let changedSnapAfter: ObjectReference = try #require(changed.component())
        let unchangedSnapAfter: ObjectReference = try #require(unchanged.component())

        #expect(changed.objectID == firstObjectID)
        #expect(unchanged.objectID == secondObjectID)
        
        #expect(changedSnapBefore.snapshotID != changedSnapAfter.snapshotID)
        #expect(unchangedSnapBefore.snapshotID == unchangedSnapAfter.snapshotID)
    }

    @Test func preserveRelationships() throws {
        // Current limitation: mutation despawns the old entity, so any
        // `RepresentationOf` relationship pointing to it is cascade-removed.
        let world = World(plane: frameWithTwo)
        let first = try #require(world.entity(firstObjectID))
        let second = try #require(world.entity(secondObjectID))

        let rep1: RuntimeEntity = world.spawn()
        rep1.relate(RepresentationOf(), to: first)
        let rep2: RuntimeEntity = world.spawn()
        rep2.relate(RepresentationOf(), to: second)

        world.setPlane(frameWithMutation)

        #expect(rep1.target(RepresentationOf.self)?.runtimeID == first.runtimeID)
        #expect(rep2.target(RepresentationOf.self)?.runtimeID == second.runtimeID)
    }
}
