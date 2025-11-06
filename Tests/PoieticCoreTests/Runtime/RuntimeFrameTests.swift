//
//  RuntimeFrameTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 30/10/2024.
//

import Testing
@testable import PoieticCore

// Test frame-level component
struct TestFrameComponent: Component, Equatable {
    var orderedIDs: [ObjectID]

    init(orderedIDs: [ObjectID] = []) {
        self.orderedIDs = orderedIDs
    }
}

@Suite struct RuntimeFrameTests {
    let design: Design
    let validatedFrame: DesignFrame
    let objectIDs: [ObjectID]  // IDs of created objects for easy reference

    init() throws {
        // Create a test design with a few objects
        self.design = Design(metamodel: TestMetamodel)
        let frame = design.createFrame()

        // Create some test objects with proper structure
        let obj1 = frame.create(.Stock, structure: .node)
        let obj2 = frame.create(.FlowRate, structure: .node)
        let obj3 = frame.create(.Stock, structure: .node)

        self.objectIDs = [obj1.objectID, obj2.objectID, obj3.objectID]

        // Accept and validate
        self.validatedFrame = try design.accept(frame)
    }

    // MARK: - Basics

    @Test func createRuntimeFrame() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        #expect(runtimeFrame.id == validatedFrame.id)
        #expect(runtimeFrame.snapshots.count == 3)
        #expect(!runtimeFrame.hasIssues)
    }

    @Test func delegatesFrameProtocol() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        // Should delegate all Frame protocol methods
        #expect(runtimeFrame.contains(objectIDs[0]))
        #expect(runtimeFrame.object(objectIDs[0]) != nil)
        #expect(runtimeFrame.objectIDs.count == 3)
        #expect(runtimeFrame.design === design)
    }

    // MARK: - Object Components

    @Test func setAndGetComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        let component = TestComponent(text: "test value")
        runtimeFrame.setComponent(component, for: objectID)

        let retrieved: TestComponent = try #require(runtimeFrame.component(for: objectID))
        #expect(retrieved.text == "test value")
    }

    @Test func getComponentReturnsNilWhenNotSet() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        let component: TestComponent? = runtimeFrame.component(for: objectID)
        #expect(component == nil)
    }

    @Test func replaceComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        runtimeFrame.setComponent(TestComponent(text: "first"), for: objectID)
        runtimeFrame.setComponent(TestComponent(text: "second"), for: objectID)

        let retrieved: TestComponent = try #require(runtimeFrame.component(for: objectID))
        #expect(retrieved.text == "second")
    }

    @Test func hasComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        #expect(!runtimeFrame.hasComponent(TestComponent.self, for: objectID))

        runtimeFrame.setComponent(TestComponent(text: "test"), for: objectID)

        #expect(runtimeFrame.hasComponent(TestComponent.self, for: objectID))
    }

    @Test func removeComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        runtimeFrame.setComponent(TestComponent(text: "test"), for: objectID)
        #expect(runtimeFrame.hasComponent(TestComponent.self, for: objectID))

        runtimeFrame.removeComponent(TestComponent.self, for: objectID)

        #expect(!runtimeFrame.hasComponent(TestComponent.self, for: objectID))
        let retrieved: TestComponent? = runtimeFrame.component(for: objectID)
        #expect(retrieved == nil)
    }

    @Test func multipleComponentsPerObject() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        runtimeFrame.setComponent(TestComponent(text: "test"), for: objectID)
        runtimeFrame.setComponent(IntegerComponent(value: 42), for: objectID)

        let testComp: TestComponent = try #require(runtimeFrame.component(for: objectID))
        let intComp: IntegerComponent = try #require(runtimeFrame.component(for: objectID))

        #expect(testComp.text == "test")
        #expect(intComp.value == 42)
    }

    @Test func componentsIsolatedPerObject() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let obj1 = objectIDs[0]
        let obj2 = objectIDs[1]

        runtimeFrame.setComponent(TestComponent(text: "obj1"), for: obj1)
        runtimeFrame.setComponent(TestComponent(text: "obj2"), for: obj2)

        let comp1: TestComponent = try #require(runtimeFrame.component(for: obj1))
        let comp2: TestComponent = try #require(runtimeFrame.component(for: obj2))

        #expect(comp1.text == "obj1")
        #expect(comp2.text == "obj2")
    }

    // MARK: - Query

    @Test func objectIDsWithComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        var withComponent = runtimeFrame.objectIDs(with: TestComponent.self)
        #expect(withComponent.isEmpty)

        runtimeFrame.setComponent(TestComponent(text: "test1"), for: objectIDs[0])
        runtimeFrame.setComponent(TestComponent(text: "test2"), for: objectIDs[2])

        withComponent = runtimeFrame.objectIDs(with: TestComponent.self)
        #expect(withComponent.count == 2)
        #expect(withComponent.contains(objectIDs[0]))
        #expect(withComponent.contains(objectIDs[2]))
        #expect(!withComponent.contains(objectIDs[1]))
    }

    @Test func queryByDifferentComponentTypes() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        runtimeFrame.setComponent(TestComponent(text: "test"), for: objectIDs[0])
        runtimeFrame.setComponent(IntegerComponent(value: 42), for: objectIDs[1])
        runtimeFrame.setComponent(TestComponent(text: "test2"), for: objectIDs[2])

        let withText = runtimeFrame.objectIDs(with: TestComponent.self)
        let withInt = runtimeFrame.objectIDs(with: IntegerComponent.self)

        #expect(withText.count == 2)
        #expect(withInt.count == 1)
        #expect(withText.contains(objectIDs[0]))
        #expect(withText.contains(objectIDs[2]))
        #expect(withInt.contains(objectIDs[1]))
    }

    // MARK: - Frame

    @Test func setAndGetFrameComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        let component = TestFrameComponent(orderedIDs: objectIDs)
        runtimeFrame.setFrameComponent(component)

        let retrieved: TestFrameComponent = try #require(runtimeFrame.frameComponent(TestFrameComponent.self))
        #expect(retrieved.orderedIDs == objectIDs)
    }

    @Test func getFrameComponentReturnsNilWhenNotSet() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        let component: TestFrameComponent? = runtimeFrame.frameComponent(TestFrameComponent.self)
        #expect(component == nil)
    }

    @Test func replaceFrameComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        runtimeFrame.setFrameComponent(TestFrameComponent(orderedIDs: [objectIDs[0]]))
        runtimeFrame.setFrameComponent(TestFrameComponent(orderedIDs: objectIDs))

        let retrieved: TestFrameComponent = try #require(runtimeFrame.frameComponent(TestFrameComponent.self))
        #expect(retrieved.orderedIDs.count == 3)
    }

    @Test func hasFrameComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        #expect(!runtimeFrame.hasFrameComponent(TestFrameComponent.self))

        runtimeFrame.setFrameComponent(TestFrameComponent(orderedIDs: objectIDs))

        #expect(runtimeFrame.hasFrameComponent(TestFrameComponent.self))
    }

    @Test func removeFrameComponent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        // Set frame component
        runtimeFrame.setFrameComponent(TestFrameComponent(orderedIDs: objectIDs))
        #expect(runtimeFrame.hasFrameComponent(TestFrameComponent.self))

        // Remove it
        runtimeFrame.removeFrameComponent(TestFrameComponent.self)

        #expect(!runtimeFrame.hasFrameComponent(TestFrameComponent.self))
        let retrieved: TestFrameComponent? = runtimeFrame.frameComponent(TestFrameComponent.self)
        #expect(retrieved == nil)
    }

    @Test func multipleFrameComponents() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)

        runtimeFrame.setFrameComponent(TestFrameComponent(orderedIDs: objectIDs))
        runtimeFrame.setFrameComponent(IntegerComponent(value: 100))

        let orderComp: TestFrameComponent = try #require(runtimeFrame.frameComponent(TestFrameComponent.self))
        let intComp: IntegerComponent = try #require(runtimeFrame.frameComponent(IntegerComponent.self))

        #expect(orderComp.orderedIDs.count == 3)
        #expect(intComp.value == 100)
    }

    // MARK: - Object vs Frame Components

    @Test func objectAndFrameComponentsAreIndependent() throws {
        let runtimeFrame = RuntimeFrame(validatedFrame)
        let objectID = objectIDs[0]

        runtimeFrame.setComponent(IntegerComponent(value: 8), for: objectID)
        runtimeFrame.setFrameComponent(IntegerComponent(value: 100))

        let objectComp: IntegerComponent = try #require(runtimeFrame.component(for: objectID))
        let frameComp: IntegerComponent = try #require(runtimeFrame.frameComponent(IntegerComponent.self))

        #expect(objectComp.value == 8)
        #expect(frameComp.value == 100)
    }
}
