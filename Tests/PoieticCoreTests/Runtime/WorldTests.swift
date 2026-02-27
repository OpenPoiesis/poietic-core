//
//  AugmentedFrameTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 30/10/2024.
//

import Testing
@testable import PoieticCore

struct TestFrameComponent: Component, Equatable {
    var orderedIDs: [ObjectID]

    init(orderedIDs: [ObjectID] = []) {
        self.orderedIDs = orderedIDs
    }
}

@Suite struct WorldTests {
    let design: Design
    let emptyFrame: DesignFrame
    let testFrame: DesignFrame
    let objectIDs: [ObjectID]  // IDs of created objects for easy reference

    init() throws {
        // Create a test design with a few objects
        self.design = Design(metamodel: TestMetamodel)
        let trans1 = design.createFrame()

        self.emptyFrame = try design.accept(trans1)
        
        let trans2 = design.createFrame()

        // Create some test objects with proper structure
        let obj1 = trans2.create(.Stock, structure: .node)
        let obj2 = trans2.create(.FlowRate, structure: .node)
        let obj3 = trans2.create(.Stock, structure: .node)
        self.objectIDs = [obj1.objectID, obj2.objectID, obj3.objectID]
        self.testFrame = try design.accept(trans2)
    }

    // MARK: - Basics

    @Test func createWorld() throws {
        let world = World(frame: emptyFrame)

        #expect(world.entities.count == 0)
        #expect(!world.hasIssues)
    }
    
//    @Test func setFrame() throws {
//        let world = World(frame: self.frame)
//        let trans = design.createFrame()
//        for id in self.frame.objectIDs {
//            trans.removeCascading(id)
//        }
//        let obj = trans.create(.Stock, structure: .node)
//        let newFrame = try self.design.accept(trans)
//        world.setFrame(newFrame.id)
//        
//        #expect(world.entities.count == 1)
//        let ent = try #require(world.entities.first)
//        #expect(ent == world.objectToEntity(obj.objectID))
//    }
//
    
    // MARK: - Spawn/Despawn
    @Test func spawn() throws {
        let world = World(frame: self.emptyFrame)
        let ent: RuntimeEntity = world.spawn(TestComponent(text: "test"))
        
        #expect(world.entities.count == 1)
        #expect(world.contains(ent))
    
        let component: TestComponent = try #require(ent.component())
        #expect(component.text == "test")
    }
    @Test func despawn() throws {
        let world = World(frame: self.emptyFrame)
        let ent: RuntimeEntity = world.spawn(TestComponent(text: "test"))
        world.despawn(ent)
        
        #expect(world.entities.count == 0)
        #expect(!world.contains(ent))
        let component: TestComponent? = ent.component()
        #expect(component == nil)
    }

    // MARK: - Dependencies
    @Test func setDependency() throws {
        let world = World(frame: self.emptyFrame)
        let parent: RuntimeEntity = world.spawn()
        let child: RuntimeEntity = world.spawn()
        world.setDependency(of: child.runtimeID, on: parent.runtimeID)
        world.despawn(parent)
        #expect(!world.contains(parent))
        #expect(!world.contains(child))
    }
    @Test func setIndirectDependency() throws {
        let world = World(frame: self.emptyFrame)
        let a: RuntimeEntity = world.spawn()
        let b: RuntimeEntity = world.spawn()
        let c: RuntimeEntity = world.spawn()
        world.setDependency(of: b.runtimeID, on: a.runtimeID)
        world.setDependency(of: c.runtimeID, on: b.runtimeID)
        world.despawn(a)
        #expect(!world.contains(a))
        #expect(!world.contains(b))
        #expect(!world.contains(c))
    }

    // MARK: - Components
    @Test func setAndGetComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent: RuntimeEntity = world.spawn()

        #expect(!ent.contains(TestComponent.self))
        let empty: TestComponent? = ent.component()
        #expect(empty == nil)

        ent.setComponent(TestComponent(text: "test"))
        #expect(ent.contains(TestComponent.self))

        let retrieved: TestComponent = try #require(ent.component())
        #expect(retrieved.text == "test")

    }
    
    @Test func replaceComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent: RuntimeEntity = world.spawn()

        ent.setComponent(TestComponent(text: "first"))
        ent.setComponent(TestComponent(text: "second"))

        let retrieved: TestComponent = try #require(ent.component())
        #expect(retrieved.text == "second")
    }

    @Test func removeComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent: RuntimeEntity = world.spawn()

        ent.setComponent(TestComponent(text: "test"))
        #expect(ent.contains(TestComponent.self))
        ent.removeComponent(TestComponent.self)
        #expect(!ent.contains(TestComponent.self))

        let empty: TestComponent? = ent.component()
        #expect(empty == nil)
    }

    @Test func multipleComponentsPerEntity() throws {
        let world = World(frame: self.emptyFrame)
        let ent: RuntimeEntity = world.spawn()

        ent.setComponent(TestComponent(text: "test"))
        ent.setComponent(IntegerComponent(value: 1024))

        let testComp: TestComponent = try #require(ent.component())
        let intComp: IntegerComponent = try #require(ent.component())

        #expect(testComp.text == "test")
        #expect(intComp.value == 1024)
    }

    @Test func componentsIsolatedPerEntity() throws {
        let world = World(frame: self.emptyFrame)
        let ent1: RuntimeEntity = world.spawn()
        let ent2: RuntimeEntity = world.spawn()

        ent1.setComponent(TestComponent(text: "obj1"))
        ent2.setComponent(TestComponent(text: "obj2"))

        let comp1: TestComponent = try #require(ent1.component())
        let comp2: TestComponent = try #require(ent2.component())

        #expect(comp1.text == "obj1")
        #expect(comp2.text == "obj2")
    }

    // MARK: - Query

    @Test func queryComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent1: RuntimeEntity = world.spawn()
        let ent2: RuntimeEntity = world.spawn()
        let ent3: RuntimeEntity = world.spawn()

        var empty: QueryResult<RuntimeEntity> = world.query(TestComponent.self)
        #expect(empty.next() == nil)
        
        ent1.setComponent(TestComponent(text: "test1"))
        ent2.setComponent(TestComponent(text: "test2"))
        
        let some: QueryResult<RuntimeEntity> = world.query(TestComponent.self)
        let ids: [RuntimeID] = some.map { $0.runtimeID }
        #expect(ids.count == 2)
        #expect(ids.contains(ent1.runtimeID))
        #expect(ids.contains(ent2.runtimeID))
        #expect(!ids.contains(ent3.runtimeID))
    }

    @Test func querySkipsNonMatchingEntities() throws {
        let world = World(frame: self.emptyFrame)
        
        let ent1: RuntimeEntity = world.spawn(TestComponent(text: "first"))
        let ent2: RuntimeEntity = world.spawn(IntegerComponent(value: 10))
        let ent3: RuntimeEntity = world.spawn(IntegerComponent(value: 20))
        let ent4: RuntimeEntity = world.spawn(TestComponent(text: "second"))
        let ent5: RuntimeEntity = world.spawn(IntegerComponent(value: 30))
        let ent6: RuntimeEntity = world.spawn(TestComponent(text: "third"))
        
        let results: Array<RuntimeEntity> = Array(world.query(TestComponent.self))
        
        #expect(results.count == 3)
        // Matches
        #expect(results.contains(where: { $0.runtimeID == ent1.runtimeID }))
        #expect(results.contains(where: { $0.runtimeID == ent4.runtimeID }))
        #expect(results.contains(where: { $0.runtimeID == ent6.runtimeID }))
        
        // Non-matches
        #expect(!results.contains(where: { $0.runtimeID == ent2.runtimeID }))
        #expect(!results.contains(where: { $0.runtimeID == ent3.runtimeID }))
        #expect(!results.contains(where: { $0.runtimeID == ent5.runtimeID }))
    }
    
    @Test func queryDifferentComponents() throws {
        let world = World(frame: self.emptyFrame)
        let entT1: RuntimeEntity = world.spawn(TestComponent(text: "test"))
        let entT2: RuntimeEntity = world.spawn(TestComponent(text: "test2"))
        let entI: RuntimeEntity = world.spawn(IntegerComponent(value: 42))

        let withText: Array<RuntimeEntity> = Array(world.query(TestComponent.self))
        #expect(withText.count == 2)
        #expect(withText.contains(where: {$0.runtimeID == entT1.runtimeID}))
        #expect(withText.contains(where: {$0.runtimeID == entT2.runtimeID}))
       
        let withInt: Array<RuntimeEntity> = Array(world.query(IntegerComponent.self))
        #expect(withInt.count == 1)
        #expect(withInt.contains(where: {$0.runtimeID == entI.runtimeID}))
    }
    
    // MARK: - Frame
    @Test func frameObjectEntities() throws {
        let world = World(frame: self.testFrame)
        
        let ent0 = try #require(world.objectToEntity(objectIDs[0]))
        #expect(world.entityToObject(ent0) == objectIDs[0])
        #expect(world.contains(ent0))
        let ent1 = try #require(world.objectToEntity(objectIDs[1]))
        #expect(world.entityToObject(ent1) == objectIDs[1])
        #expect(world.contains(ent1))
        let ent2 = try #require(world.objectToEntity(objectIDs[2]))
        #expect(world.entityToObject(ent2) == objectIDs[2])
        #expect(world.contains(ent2))
    }
    @Test func frameRemovedObjects() throws {
        let world = World(frame: self.testFrame)
        world.setFrame(self.emptyFrame)
        #expect(world.entities.count == 0)
        
        #expect(world.objectToEntity(objectIDs[0]) == nil)
        #expect(world.objectToEntity(objectIDs[1]) == nil)
        #expect(world.objectToEntity(objectIDs[2]) == nil)
    }
    @Test func frameAddedObjects() throws {
        let world = World(frame: self.emptyFrame)
        world.setFrame(self.testFrame)
        #expect(world.entities.count == 3)
        
        #expect(world.objectToEntity(objectIDs[0]) != nil)
        #expect(world.objectToEntity(objectIDs[1]) != nil)
        #expect(world.objectToEntity(objectIDs[2]) != nil)
    }
    // MARK: - Singleton
    @Test func setAndGetSingletonComponent() throws {
        let world = World(frame: self.emptyFrame)

        let component = TestFrameComponent(orderedIDs: objectIDs)
        world.setSingleton(component)

        let retrieved: TestFrameComponent = try #require(world.singleton())
        #expect(retrieved.orderedIDs == objectIDs)
    }

    @Test func getFrameComponentReturnsNilWhenNotSet() throws {
        let world = World(frame: self.emptyFrame)

        let component: TestFrameComponent? = world.singleton()
        #expect(component == nil)
    }

    @Test func replaceFrameComponent() throws {
        let world = World(frame: self.emptyFrame)

        world.setSingleton(TestFrameComponent(orderedIDs: [objectIDs[0]]))
        world.setSingleton(TestFrameComponent(orderedIDs: objectIDs))

        let retrieved: TestFrameComponent = try #require(world.singleton())
        #expect(retrieved.orderedIDs.count == 3)
    }

    @Test func hasFrameComponent() throws {
        let world = World(frame: emptyFrame)

        #expect(!world.hasSingleton(TestFrameComponent.self))

        world.setSingleton(TestFrameComponent(orderedIDs: objectIDs))

        #expect(world.hasSingleton(TestFrameComponent.self))
    }

    @Test func removeFrameComponent() throws {
        let world = World(frame: emptyFrame)

        // Set frame component
        world.setSingleton(TestFrameComponent(orderedIDs: objectIDs))
        #expect(world.hasSingleton(TestFrameComponent.self))

        // Remove it
        world.removeSingleton(TestFrameComponent.self)

        #expect(!world.hasSingleton(TestFrameComponent.self))
        let retrieved: TestFrameComponent? = world.singleton()
        #expect(retrieved == nil)
    }

    @Test func multipleFrameComponents() throws {
        let world = World(frame: emptyFrame)

        world.setSingleton(TestFrameComponent(orderedIDs: objectIDs))
        world.setSingleton(IntegerComponent(value: 100))

        let orderComp: TestFrameComponent = try #require(world.singleton())
        let intComp: IntegerComponent = try #require(world.singleton())

        #expect(orderComp.orderedIDs.count == 3)
        #expect(intComp.value == 100)
    }
}
