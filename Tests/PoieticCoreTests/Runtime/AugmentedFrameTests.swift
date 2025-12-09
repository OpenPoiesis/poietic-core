//
//  AugmentedFrameTests.swift
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

@Suite struct AugmentedFrameTests {
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

    @Test func createaugmented() throws {
        let augmented = AugmentedFrame(validatedFrame)

        #expect(augmented.id == validatedFrame.id)
        #expect(augmented.snapshots.count == 3)
        #expect(!augmented.hasIssues)
    }

    @Test func delegatesFrameProtocol() throws {
        let augmented = AugmentedFrame(validatedFrame)

        // Should delegate all Frame protocol methods
        #expect(augmented.contains(objectIDs[0]))
        #expect(augmented.object(objectIDs[0]) != nil)
        #expect(augmented.objectIDs.count == 3)
        #expect(augmented.design === design)
    }

    // MARK: - Object Components

    @Test func setAndGetComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        let component = TestComponent(text: "test value")
        augmented.setComponent(component, for: .object(objectID))

        let retrieved: TestComponent = try #require(augmented.component(for: .object(objectID)))
        #expect(retrieved.text == "test value")
    }

    @Test func getComponentReturnsNilWhenNotSet() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        let component: TestComponent? = augmented.component(for: .object(objectID))
        #expect(component == nil)
    }

    @Test func replaceComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        augmented.setComponent(TestComponent(text: "first"), for: .object(objectID))
        augmented.setComponent(TestComponent(text: "second"), for: .object(objectID))

        let retrieved: TestComponent = try #require(augmented.component(for: .object(objectID)))
        #expect(retrieved.text == "second")
    }

    @Test func hasComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        #expect(!augmented.hasComponent(TestComponent.self, for: .object(objectID)))

        augmented.setComponent(TestComponent(text: "test"), for: .object(objectID))

        #expect(augmented.hasComponent(TestComponent.self, for: .object(objectID)))
    }

    @Test func removeComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        augmented.setComponent(TestComponent(text: "test"), for: .object(objectID))
        #expect(augmented.hasComponent(TestComponent.self, for: .object(objectID)))

        augmented.removeComponent(TestComponent.self, for: .object(objectID))

        #expect(!augmented.hasComponent(TestComponent.self, for: .object(objectID)))
        let retrieved: TestComponent? = augmented.component(for: .object(objectID))
        #expect(retrieved == nil)
    }

    @Test func multipleComponentsPerObject() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        augmented.setComponent(TestComponent(text: "test"), for: .object(objectID))
        augmented.setComponent(IntegerComponent(value: 42), for: .object(objectID))

        let testComp: TestComponent = try #require(augmented.component(for: .object(objectID)))
        let intComp: IntegerComponent = try #require(augmented.component(for: .object(objectID)))

        #expect(testComp.text == "test")
        #expect(intComp.value == 42)
    }

    @Test func componentsIsolatedPerObject() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let obj1 = objectIDs[0]
        let obj2 = objectIDs[1]

        augmented.setComponent(TestComponent(text: "obj1"), for: .object(obj1))
        augmented.setComponent(TestComponent(text: "obj2"), for: .object(obj2))

        let comp1: TestComponent = try #require(augmented.component(for: .object(obj1)))
        let comp2: TestComponent = try #require(augmented.component(for: .object(obj2)))

        #expect(comp1.text == "obj1")
        #expect(comp2.text == "obj2")
    }

    // MARK: - Query

    @Test func objectIDsWithComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)

        var withComponent = augmented.objectIDs(with: TestComponent.self)
        #expect(withComponent.isEmpty)

        augmented.setComponent(TestComponent(text: "test1"), for: .object(objectIDs[0]))
        augmented.setComponent(TestComponent(text: "test2"), for: .object(objectIDs[2]))

        withComponent = augmented.objectIDs(with: TestComponent.self)
        #expect(withComponent.count == 2)
        #expect(withComponent.contains(objectIDs[0]))
        #expect(withComponent.contains(objectIDs[2]))
        #expect(!withComponent.contains(objectIDs[1]))
    }

    @Test func queryByDifferentComponentTypes() throws {
        let augmented = AugmentedFrame(validatedFrame)

        augmented.setComponent(TestComponent(text: "test"), for: .object(objectIDs[0]))
        augmented.setComponent(IntegerComponent(value: 42), for: .object(objectIDs[1]))
        augmented.setComponent(TestComponent(text: "test2"), for: .object(objectIDs[2]))

        let withText = augmented.objectIDs(with: TestComponent.self)
        let withInt = augmented.objectIDs(with: IntegerComponent.self)

        #expect(withText.count == 2)
        #expect(withInt.count == 1)
        #expect(withText.contains(objectIDs[0]))
        #expect(withText.contains(objectIDs[2]))
        #expect(withInt.contains(objectIDs[1]))
    }

    // MARK: - Frame

    @Test func setAndGetFrameComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)

        let component = TestFrameComponent(orderedIDs: objectIDs)
        augmented.setComponent(component, for: .Frame)

        let retrieved: TestFrameComponent = try #require(augmented.component(for: .Frame))
        #expect(retrieved.orderedIDs == objectIDs)
    }

    @Test func getFrameComponentReturnsNilWhenNotSet() throws {
        let augmented = AugmentedFrame(validatedFrame)

        let component: TestFrameComponent? = augmented.component(for: .Frame)
        #expect(component == nil)
    }

    @Test func replaceFrameComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)

        augmented.setComponent(TestFrameComponent(orderedIDs: [objectIDs[0]]), for: .Frame)
        augmented.setComponent(TestFrameComponent(orderedIDs: objectIDs), for: .Frame)

        let retrieved: TestFrameComponent = try #require(augmented.component(for: .Frame))
        #expect(retrieved.orderedIDs.count == 3)
    }

    @Test func hasFrameComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)

        #expect(!augmented.hasComponent(TestFrameComponent.self, for: .Frame))

        augmented.setComponent(TestFrameComponent(orderedIDs: objectIDs), for: .Frame)

        #expect(augmented.hasComponent(TestFrameComponent.self, for: .Frame))
    }

    @Test func removeFrameComponent() throws {
        let augmented = AugmentedFrame(validatedFrame)

        // Set frame component
        augmented.setComponent(TestFrameComponent(orderedIDs: objectIDs), for: .Frame)
        #expect(augmented.hasComponent(TestFrameComponent.self, for: .Frame))

        // Remove it
        augmented.removeComponent(TestFrameComponent.self, for: .Frame)

        #expect(!augmented.hasComponent(TestFrameComponent.self, for: .Frame))
        let retrieved: TestFrameComponent? = augmented.component(for: .Frame)
        #expect(retrieved == nil)
    }

    @Test func multipleFrameComponents() throws {
        let augmented = AugmentedFrame(validatedFrame)

        augmented.setComponent(TestFrameComponent(orderedIDs: objectIDs), for: .Frame)
        augmented.setComponent(IntegerComponent(value: 100), for: .Frame)

        let orderComp: TestFrameComponent = try #require(augmented.component(for: .Frame))
        let intComp: IntegerComponent = try #require(augmented.component(for: .Frame))

        #expect(orderComp.orderedIDs.count == 3)
        #expect(intComp.value == 100)
    }

    // MARK: - Object vs Frame Components

    @Test func objectAndFrameComponentsAreIndependent() throws {
        let augmented = AugmentedFrame(validatedFrame)
        let objectID = objectIDs[0]

        augmented.setComponent(IntegerComponent(value: 8), for: .object(objectID))
        augmented.setComponent(IntegerComponent(value: 100), for: .Frame)

        let objectComp: IntegerComponent = try #require(augmented.component(for: .object(objectID)))
        let frameComp: IntegerComponent = try #require(augmented.component(for: .Frame))

        #expect(objectComp.value == 8)
        #expect(frameComp.value == 100)
    }
}
