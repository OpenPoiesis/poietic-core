//
//  AugmentedFrameTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 30/10/2024.
//

import Testing
@testable import PoieticCore

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
        let ent = world.spawn(TestComponent(text: "test"))
        
        #expect(world.entities.count == 1)
        #expect(world.contains(ent))
    
        let component: TestComponent = try #require(world.component(for: ent))
        #expect(component.text == "test")
    }
    @Test func despawn() throws {
        let world = World(frame: self.emptyFrame)
        let ent = world.spawn(TestComponent(text: "test"))
        world.despawn(ent)
        
        #expect(world.entities.count == 0)
        #expect(!world.contains(ent))
        let component: TestComponent? = world.component(for: ent)
        #expect(component == nil)
    }

    // MARK: - Dependencies
    @Test func setDependency() throws {
        let world = World(frame: self.emptyFrame)
        let parent = world.spawn()
        let child = world.spawn()
        world.setDependency(of: child, on: parent)
        world.despawn(parent)
        #expect(!world.contains(parent))
        #expect(!world.contains(child))
    }
    @Test func setIndirectDependency() throws {
        let world = World(frame: self.emptyFrame)
        let a = world.spawn()
        let b = world.spawn()
        let c = world.spawn()
        world.setDependency(of: b, on: a)
        world.setDependency(of: c, on: b)
        world.despawn(a)
        #expect(!world.contains(a))
        #expect(!world.contains(b))
        #expect(!world.contains(c))
    }

    // MARK: - Components
    @Test func setAndGetComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent = world.spawn()

        #expect(!world.hasComponent(TestComponent.self, for: ent))
        let empty: TestComponent? = world.component(for: ent)
        #expect(empty == nil)

        world.setComponent(TestComponent(text: "test"), for: ent)
        #expect(world.hasComponent(TestComponent.self, for: ent))

        let retrieved: TestComponent = try #require(world.component(for: ent))
        #expect(retrieved.text == "test")

    }
    
    @Test func replaceComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent = world.spawn()

        world.setComponent(TestComponent(text: "first"), for: ent)
        world.setComponent(TestComponent(text: "second"), for: ent)

        let retrieved: TestComponent = try #require(world.component(for: ent))
        #expect(retrieved.text == "second")
    }

    @Test func removeComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent = world.spawn()

        world.setComponent(TestComponent(text: "test"), for: ent)
        #expect(world.hasComponent(TestComponent.self, for: ent))
        world.removeComponent(TestComponent.self, for: ent)
        #expect(!world.hasComponent(TestComponent.self, for: ent))

        let empty: TestComponent? = world.component(for: ent)
        #expect(empty == nil)
    }

    @Test func multipleComponentsPerEntity() throws {
        let world = World(frame: self.emptyFrame)
        let ent = world.spawn()

        world.setComponent(TestComponent(text: "test"), for: ent)
        world.setComponent(IntegerComponent(value: 1024), for: ent)

        let testComp: TestComponent = try #require(world.component(for: ent))
        let intComp: IntegerComponent = try #require(world.component(for: ent))

        #expect(testComp.text == "test")
        #expect(intComp.value == 1024)
    }

    @Test func componentsIsolatedPerEntity() throws {
        let world = World(frame: self.emptyFrame)
        let ent1 = world.spawn()
        let ent2 = world.spawn()

        world.setComponent(TestComponent(text: "obj1"), for: ent1)
        world.setComponent(TestComponent(text: "obj2"), for: ent2)

        let comp1: TestComponent = try #require(world.component(for: ent1))
        let comp2: TestComponent = try #require(world.component(for: ent2))

        #expect(comp1.text == "obj1")
        #expect(comp2.text == "obj2")
    }

    // MARK: - Query

    @Test func queryComponent() throws {
        let world = World(frame: self.emptyFrame)
        let ent1 = world.spawn()
        let ent2 = world.spawn()
        let ent3 = world.spawn()

        let empty = world.query(TestComponent.self)
        #expect(empty.isEmpty)
        
        world.setComponent(TestComponent(text: "test1"), for: ent1)
        world.setComponent(TestComponent(text: "test2"), for: ent2)
        
        let some = world.query(TestComponent.self)
        let ids = some.map { $0.0 }
        #expect(some.count == 2)
        #expect(ids.contains(ent1))
        #expect(ids.contains(ent2))
        #expect(!ids.contains(ent3))
    }

    @Test func queryDifferentComponents() throws {
        let world = World(frame: self.emptyFrame)
        let ent1 = world.spawn()
        let ent2 = world.spawn()
        let ent3 = world.spawn()

        world.setComponent(TestComponent(text: "test"), for: ent1)
        world.setComponent(IntegerComponent(value: 42), for: ent2)
        world.setComponent(TestComponent(text: "test2"), for: ent3)

        let withText = world.query(TestComponent.self)
        let withInt = world.query(IntegerComponent.self)

        #expect(withText.count == 2)
        #expect(withInt.count == 1)
        #expect(withText.contains(ent1))
        #expect(withText.contains(ent3))
        #expect(withInt.contains(ent2))
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
