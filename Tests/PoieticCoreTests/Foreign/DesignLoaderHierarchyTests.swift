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
            rawPlanes: []
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
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)),
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
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(300), objectID: .int(30), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(400), objectID: .int(40), parent: .int(10)),
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
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(300), objectID: .int(30), parent: .int(20)),
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
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10), parent: .int(999)),
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

    @Test("Hierarchy with planes - consistent children")
    func hierarchyWithFramesConsistent() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(300), objectID: .int(20), parent: .int(10)),
            ],
            rawPlanes: [
                RawPlane(id: .int(1000), snapshots: [.int(100), .int(200)]),
                RawPlane(id: .int(1001), snapshots: [.int(100), .int(300)]),
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
        let planeResolution = try loader.resolvePlanes(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(
            planeResolution: planeResolution,
            snapshotResolution: partialSnapshots
        )

        #expect(hierarchy.objectSnapshots.count == 3)
        #expect(hierarchy.children.count == 1)
        #expect(hierarchy.children[ObjectSnapshotID(100)] == [ObjectID(20)])
    }

    @Test("Children mismatch error - none to some")
    func childrenMismatchNoneToSome() async throws {
        // Plane 1000: parent has no children (child not in plane)
        // Plane 1001: parent has one child
        // This MUST throw error because the same snapshot ID (100) appears in both planes
        // with different children (nil vs [20]). When a parent gains a child, it should be
        // a new snapshot with a new snapshot ID.
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)),
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)),
            ],
            rawPlanes: [
                RawPlane(id: .int(1000), snapshots: [.int(100)]), // parent only
                RawPlane(id: .int(1001), snapshots: [.int(100), .int(200)]), // parent + child
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
        let planeResolution = try loader.resolvePlanes(
            resolution: validation,
            identities: identities
        )

        #expect(throws: DesignLoaderError.item(.planes, 1, .childrenMismatch)) {
            _ = try loader.resolveHierarchy(
                planeResolution: planeResolution,
                snapshotResolution: partialSnapshots
            )
        }
    }

    @Test("Children mismatch error - some to none")
    func childrenMismatchSomeToNone() async throws {
        // Plane 1000: parent has one child
        // Frame 1001: parent has no children (child not in plane)
        // This MUST throw error because the same snapshot ID (100) appears in both planes
        // with different children ([20] vs nil). When a parent loses a child, it should be
        // a new snapshot with a new snapshot ID.
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)), // parent
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)), // child
            ],
            rawPlanes: [
                RawPlane(id: .int(1000), snapshots: [.int(100), .int(200)]), // parent + child
                RawPlane(id: .int(1001), snapshots: [.int(100)]), // parent only
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
        let planeResolution = try loader.resolvePlanes(
            resolution: validation,
            identities: identities
        )

        #expect(throws: DesignLoaderError.item(.planes, 1, .childrenMismatch)) {
            _ = try loader.resolveHierarchy(
                planeResolution: planeResolution,
                snapshotResolution: partialSnapshots
            )
        }
    }

    @Test("Children mismatch error - different children")
    func childrenMismatchDifferentChildren() async throws {
        // Plane 1000: parent has child 20
        // Plane 1001: parent has child 30
        // This should fail because children lists don't match
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)), // parent
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)), // child 1
                RawSnapshot(typeName: "Test", snapshotID: .int(300), objectID: .int(30), parent: .int(10)), // child 2
            ],
            rawPlanes: [
                RawPlane(id: .int(1000), snapshots: [.int(100), .int(200)]), // parent + child 1
                RawPlane(id: .int(1001), snapshots: [.int(100), .int(300)]), // parent + child 2 (different!)
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
        let planeResolution = try loader.resolvePlanes(
            resolution: validation,
            identities: identities
        )

        #expect(throws: DesignLoaderError.item(.planes, 1, .childrenMismatch)) {
            _ = try loader.resolveHierarchy(
                planeResolution: planeResolution,
                snapshotResolution: partialSnapshots
            )
        }
    }

    @Test("Complex multi-plane hierarchy - all planes consistent")
    func complexMultiFrameHierarchy() async throws {
        // Three planes with consistent parent-child relationships
        // Important:
        // - Same snapshot ID must have same children across all planes
        // - If a child is in a plane, its parent must also be in that plane
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test", snapshotID: .int(100), objectID: .int(10)), // root
                RawSnapshot(typeName: "Test", snapshotID: .int(200), objectID: .int(20), parent: .int(10)), // child of root
                RawSnapshot(typeName: "Test", snapshotID: .int(300), objectID: .int(30), parent: .int(10)), // child of root
                RawSnapshot(typeName: "Test", snapshotID: .int(400), objectID: .int(40), parent: .int(20)), // grandchild
                RawSnapshot(typeName: "Test", snapshotID: .int(500), objectID: .int(50)), // standalone node
            ],
            rawPlanes: [
                RawPlane(id: .int(1000), snapshots: [.int(100), .int(200), .int(300), .int(400)]), // full tree
                RawPlane(id: .int(1001), snapshots: [.int(100), .int(200), .int(300), .int(400)]), // full tree again
                RawPlane(id: .int(1002), snapshots: [.int(500)]), // just standalone node
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
        let planeResolution = try loader.resolvePlanes(
            resolution: validation,
            identities: identities
        )

        let hierarchy = try loader.resolveHierarchy(
            planeResolution: planeResolution,
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
