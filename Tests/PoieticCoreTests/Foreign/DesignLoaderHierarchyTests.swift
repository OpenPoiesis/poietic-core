//
//  DesignLoaderHierarchyTests.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 22/10/2025.
//

import Testing
@testable import PoieticCore

@Suite("Design Loader: hierarchy")
struct DesignLoaderHierarchyTests {
    let strayIdentityManager: IdentityManager
    let loader: DesignLoader

    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
        self.strayIdentityManager = IdentityManager()
    }

    @Test("Empty hierarchy resolution")
    func emptyHierarchy() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [],
            rawFrames: []
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(resolution: partialSnapshots)

        #expect(hierarchy.objectSnapshots.isEmpty)
        #expect(hierarchy.children.isEmpty)
    }

    @Test("Simple parent-child relationship")
    func simpleParentChild() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)),
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(resolution: partialSnapshots)

        #expect(hierarchy.objectSnapshots.count == 2)
        #expect(hierarchy.children.count == 1)
        #expect(hierarchy.children[ObjectSnapshotID(100)] == [ObjectID(20)])
    }

    @Test("Multiple children")
    func multipleChildren() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(300), id: .int(30), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(400), id: .int(40), parent: .int(10)),
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(resolution: partialSnapshots)

        #expect(hierarchy.objectSnapshots.count == 4)
        #expect(hierarchy.children.count == 1)
        let children = try #require(hierarchy.children[ObjectSnapshotID(100)])
        #expect(children.count == 3)
        #expect(children.contains(ObjectID(20)) == true)
        #expect(children.contains(ObjectID(30)) == true)
        #expect(children.contains(ObjectID(40)) == true)
    }

    @Test("Nested hierarchy (grandchildren)")
    func nestedHierarchy() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(300), id: .int(30), parent: .int(20)),
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(resolution: partialSnapshots)

        #expect(hierarchy.objectSnapshots.count == 3)
        #expect(hierarchy.children.count == 2)
        #expect(hierarchy.children[ObjectSnapshotID(100)] == [ObjectID(20)])
        #expect(hierarchy.children[ObjectSnapshotID(200)] == [ObjectID(30)])
    }

    @Test("Unknown parent error")
    func unknownParent() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10), parent: .int(999)),
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )

        // Error happens during resolveObjectSnapshots, not resolveHierarchy
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .unknownID(.int(999)))) {
            _ = try loader.resolveObjectSnapshots(
                resolution: validation,
                identities: identities
            )
        }
    }

    @Test("Hierarchy with frames - consistent children")
    func hierarchyWithFramesConsistent() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(300), id: .int(20), parent: .int(10)),
            ],
            rawFrames: [
                RawFrame(id: .int(1000), snapshots: [.int(100), .int(200)]),
                RawFrame(id: .int(1001), snapshots: [.int(100), .int(300)]),
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )
        let frameResolution = try loader.resolveFrames(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(
            frameResolution: frameResolution,
            snapshotResolution: partialSnapshots
        )

        #expect(hierarchy.objectSnapshots.count == 3)
        #expect(hierarchy.children.count == 1)
        #expect(hierarchy.children[ObjectSnapshotID(100)] == [ObjectID(20)])
    }

    @Test("Children mismatch error - none to some")
    func childrenMismatchNoneToSome() async throws {
        // Frame 1000: parent has no children (child not in frame)
        // Frame 1001: parent has one child
        // This MUST throw error because the same snapshot ID (100) appears in both frames
        // with different children (nil vs [20]). When a parent gains a child, it should be
        // a new snapshot with a new snapshot ID.
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)),
            ],
            rawFrames: [
                RawFrame(id: .int(1000), snapshots: [.int(100)]), // parent only
                RawFrame(id: .int(1001), snapshots: [.int(100), .int(200)]), // parent + child
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )
        let frameResolution = try loader.resolveFrames(
            resolution: validation,
            identities: identities
        )

        #expect(throws: DesignLoaderError.item(.frames, 1, .childrenMismatch)) {
            _ = try loader.resolveHierarchy(
                frameResolution: frameResolution,
                snapshotResolution: partialSnapshots
            )
        }
    }

    @Test("Children mismatch error - some to none")
    func childrenMismatchSomeToNone() async throws {
        // Frame 1000: parent has one child
        // Frame 1001: parent has no children (child not in frame)
        // This MUST throw error because the same snapshot ID (100) appears in both frames
        // with different children ([20] vs nil). When a parent loses a child, it should be
        // a new snapshot with a new snapshot ID.
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)), // parent
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)), // child
            ],
            rawFrames: [
                RawFrame(id: .int(1000), snapshots: [.int(100), .int(200)]), // parent + child
                RawFrame(id: .int(1001), snapshots: [.int(100)]), // parent only
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )
        let frameResolution = try loader.resolveFrames(
            resolution: validation,
            identities: identities
        )

        #expect(throws: DesignLoaderError.item(.frames, 1, .childrenMismatch)) {
            _ = try loader.resolveHierarchy(
                frameResolution: frameResolution,
                snapshotResolution: partialSnapshots
            )
        }
    }

    @Test("Children mismatch error - different children")
    func childrenMismatchDifferentChildren() async throws {
        // Frame 1000: parent has child 20
        // Frame 1001: parent has child 30
        // This should fail because children lists don't match
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)), // parent
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)), // child 1
                RawSnapshot(typeName: "Test", snapshotID: .int(300), id: .int(30), parent: .int(10)), // child 2
            ],
            rawFrames: [
                RawFrame(id: .int(1000), snapshots: [.int(100), .int(200)]), // parent + child 1
                RawFrame(id: .int(1001), snapshots: [.int(100), .int(300)]), // parent + child 2 (different!)
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )
        let frameResolution = try loader.resolveFrames(
            resolution: validation,
            identities: identities
        )

        #expect(throws: DesignLoaderError.item(.frames, 1, .childrenMismatch)) {
            _ = try loader.resolveHierarchy(
                frameResolution: frameResolution,
                snapshotResolution: partialSnapshots
            )
        }
    }

    @Test("Complex multi-frame hierarchy - all frames consistent")
    func complexMultiFrameHierarchy() async throws {
        // Three frames with consistent parent-child relationships
        // Important:
        // - Same snapshot ID must have same children across all frames
        // - If a child is in a frame, its parent must also be in that frame
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), id: .int(10)), // root
                RawSnapshot(typeName: "Test", snapshotID: .int(200), id: .int(20), parent: .int(10)), // child of root
                RawSnapshot(typeName: "Test", snapshotID: .int(300), id: .int(30), parent: .int(10)), // child of root
                RawSnapshot(typeName: "Test", snapshotID: .int(400), id: .int(40), parent: .int(20)), // grandchild
                RawSnapshot(typeName: "Test", snapshotID: .int(500), id: .int(50)), // standalone node
            ],
            rawFrames: [
                RawFrame(id: .int(1000), snapshots: [.int(100), .int(200), .int(300), .int(400)]), // full tree
                RawFrame(id: .int(1001), snapshots: [.int(100), .int(200), .int(300), .int(400)]), // full tree again
                RawFrame(id: .int(1002), snapshots: [.int(500)]), // just standalone node
            ]
        )
        let identities = try loader.resolveIdentities(
            resolution: validation,
            identityStrategy: .requireProvided
        )
        let partialSnapshots = try loader.resolveObjectSnapshots(
            resolution: validation,
            identities: identities
        )
        let frameResolution = try loader.resolveFrames(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(
            frameResolution: frameResolution,
            snapshotResolution: partialSnapshots
        )

        #expect(hierarchy.objectSnapshots.count == 5)
        #expect(hierarchy.children.count == 2)

        // Root (100) has two children: 20 and 30
        let rootChildren = hierarchy.children[ObjectSnapshotID(100)]
        #expect(rootChildren?.count == 2)
        #expect(rootChildren?.contains(ObjectID(20)) == true)
        #expect(rootChildren?.contains(ObjectID(30)) == true)

        // Child 20 (200) has one child: 40
        #expect(hierarchy.children[ObjectSnapshotID(200)] == [ObjectID(40)])
    }
}
