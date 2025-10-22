//
//  Test.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//
// FIXME: [IMPORTANT] Recover tests


// TODO: Test createFrame when ID is reserved
// TODO: Test create object when both IDs are reserved
// TODO: Validate undo/redo is frame list
// TODO: Validate current_frame is frame

// Upgrade rules:
// 1. use structural type based on node type

import Testing
@testable import PoieticCore

@Suite("Design Loader: raw design validation")
struct DesignLoaderValidationTest {
    let strayIdentityManager: IdentityManager
    let loader: DesignLoader
    
    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
        self.strayIdentityManager = IdentityManager()
    }
    
    @Test func validateEmpty() async throws {
        let rawDesign = RawDesign()
        let result = try loader.validate(rawDesign: rawDesign,
                                         identityManager: strayIdentityManager)
        #expect(result.rawSnapshots.isEmpty)
        #expect(result.rawFrames.isEmpty)
    }
    
    @Test func duplicateSnapshotID() async throws {
        let rawDesign = RawDesign(snapshots: [
            RawSnapshot(snapshotID: .int(10)),
            RawSnapshot(snapshotID: .int(20)),
            RawSnapshot(snapshotID: .int(10)),
        ])
        
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 2, .duplicateForeignID(.int(10)))) {
            _ = try loader.validate(rawDesign: rawDesign,
                                    identityManager: strayIdentityManager)
        }
    }
    @Test func duplicateFrameID() async throws {
        let rawDesign = RawDesign(frames: [
            RawFrame(id: .int(11)),
            RawFrame(id: .int(21)),
            RawFrame(id: .int(11)),
        ])
        
        #expect(throws: DesignLoaderError.item(.frames, 2, .duplicateForeignID(.int(11)))) {
            _ = try loader.validate(rawDesign: rawDesign,
                                    identityManager: strayIdentityManager)
        }
    }

    @Test func unknownEntityType() async throws {
        let rawDesign1 = RawDesign(userReferences: [
            RawNamedReference("", type: "carrots", id: .int(1))
        ])
        
        #expect(throws: DesignLoaderError.item(.userReferences, 0, .unknownEntityType("carrots"))) {
            _ = try loader.validate(rawDesign: rawDesign1,
                                    identityManager: strayIdentityManager)
        }
        let rawDesign2 = RawDesign(systemReferences: [
            RawNamedReference("", type: "carrots", id: .int(1))
        ])
        
        #expect(throws: DesignLoaderError.item(.systemReferences, 0, .unknownEntityType("carrots"))) {
            _ = try loader.validate(rawDesign: rawDesign2,
                                    identityManager: strayIdentityManager)
        }

        let rawDesign3 = RawDesign(userLists: [
            RawNamedList("", itemType: "carrots", ids: [])
        ])
        
        #expect(throws: DesignLoaderError.item(.userLists, 0, .unknownEntityType("carrots"))) {
            _ = try loader.validate(rawDesign: rawDesign3,
                                    identityManager: strayIdentityManager)
        }

        let rawDesign4 = RawDesign(systemLists: [
            RawNamedList("", itemType: "carrots", ids: [])
        ])
        
        #expect(throws: DesignLoaderError.item(.systemLists, 0, .unknownEntityType("carrots"))) {
            _ = try loader.validate(rawDesign: rawDesign4,
                                    identityManager: strayIdentityManager)
        }
    }
    @Test func duplicateName() async throws {
        let rawDesign1 = RawDesign(userReferences: [
            RawNamedReference("ref", type: "object", id: .int(1)),
            RawNamedReference("ref", type: "object", id: .int(1)),
        ])
        
        #expect(throws: DesignLoaderError.item(.userReferences, 0, .duplicateName("ref"))) {
            _ = try loader.validate(rawDesign: rawDesign1,
                                    identityManager: strayIdentityManager)
        }
        let rawDesign2 = RawDesign(systemReferences: [
            RawNamedReference("ref", type: "object", id: .int(1)),
            RawNamedReference("ref", type: "object", id: .int(1)),
        ])
        
        #expect(throws: DesignLoaderError.item(.systemReferences, 0, .duplicateName("ref"))) {
            _ = try loader.validate(rawDesign: rawDesign2,
                                    identityManager: strayIdentityManager)
        }

        let rawDesign3 = RawDesign(userLists: [
            RawNamedList("list", itemType: "object", ids: []),
            RawNamedList("list", itemType: "object", ids: [])
        ])
        
        #expect(throws: DesignLoaderError.item(.userLists, 0, .duplicateName("list"))) {
            _ = try loader.validate(rawDesign: rawDesign3,
                                    identityManager: strayIdentityManager)
        }

        let rawDesign4 = RawDesign(systemLists: [
            RawNamedList("list", itemType: "object", ids: []),
            RawNamedList("list", itemType: "object", ids: [])
        ])
        
        #expect(throws: DesignLoaderError.item(.systemLists, 0, .duplicateName("list"))) {
            _ = try loader.validate(rawDesign: rawDesign4,
                                    identityManager: strayIdentityManager)
        }
    }

}

@Suite("Design Loader: identity reservation")
struct DesignLoaderReservationTests {
    let strayIdentityManager: IdentityManager
    let loader: DesignLoader
    
    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
        self.strayIdentityManager = IdentityManager()
    }

    @Test func empty() async throws {
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [],
            rawFrames: []
        )
        let result = try loader.resolveIdentities(resolution: resolution,
                                                  identityStrategy: .createNew)
        #expect(result.reserved.isEmpty)
        #expect(result.rawIDMap.isEmpty)
        #expect(result.frameIDs.isEmpty)
        #expect(result.snapshotIDs.isEmpty)
        #expect(result.objectIDs.isEmpty)
        #expect(result.snapshotIndex.isEmpty)
    }
    @Test("Strategy: create new IDs")
    func createNewStrategy() async throws {
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(),
                RawSnapshot(snapshotID: .int(10)),
                RawSnapshot(snapshotID: .string("thing")),
                RawSnapshot(snapshotID: .id(20)),
            ],
            rawFrames: [
                RawFrame(),
                RawFrame(id: .int(110)),
                RawFrame(id: .string("frame")),
                RawFrame(id: .id(210)),
            ]
        )
        // .createNew strategy should never raise
        let result = try loader.resolveIdentities(resolution: resolution,
                                                  identityStrategy: .createNew)
        #expect(result.reserved.count == 4 + 4 + 4) // frames + snapshots * 2 (for objects)

        #expect(result.rawIDMap.count == 6)
        #expect(result.rawIDMap[.int(10)] != nil)
        #expect(result.rawIDMap[.string("thing")] != nil)
        #expect(result.rawIDMap[.id(20)] != nil)
        #expect(result.rawIDMap[.int(110)] != nil)
        #expect(result.rawIDMap[.string("frame")] != nil)
        #expect(result.rawIDMap[.id(210)] != nil)
        
        #expect(result.frameIDs.count == 4)
        #expect(result.snapshotIDs.count == 4)
        #expect(result.objectIDs.count == 4)
        #expect(result.snapshotIndex.count == 4)
        #expect(Set(result.snapshotIndex.keys) == Set(result.snapshotIDs))
    }
    
    @Test("Strategy: require provided IDs")
    func requireProvidedStrategy() async throws {
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(snapshotID: .int(110), id: .int(10)),
                RawSnapshot(snapshotID: .int(120), id: .int(10)),
                RawSnapshot(snapshotID: .string("snap"), id: .string("object")),
            ],
            rawFrames: [
                RawFrame(id: .int(200)),
                RawFrame(id: .string("frame")),
            ]
        )
        // .createNew strategy should never raise
        let result = try loader.resolveIdentities(resolution: resolution,
                                                  identityStrategy: .requireProvided)
        #expect(result.reserved.count == 2 + 3 + 2) // fr + snap + obj

        #expect(result.rawIDMap.count == 7)
        #expect(result.rawIDMap[.int(110)] == 110)
        #expect(result.rawIDMap[.int(120)] == 120)
        #expect(result.rawIDMap[.int(10)] == 10)
        #expect(result.rawIDMap[.int(200)] == 200)

        #expect(result.rawIDMap[.string("snap")] != nil)
        #expect(result.rawIDMap[.string("object")] != nil)

        #expect(result.objectIDs.count == 3)
        #expect(result.objectIDs[0] == 10)
        #expect(result.objectIDs[1] == 10)

        #expect(result.snapshotIDs.count == 3)
        #expect(result.snapshotIDs[0] == 110)
        #expect(result.snapshotIDs[1] == 120)

        #expect(result.frameIDs.count == 2)
        #expect(result.frameIDs[0] == 200)
    }
    
    @Test("ID conflict when requiring already reserved (require)")
    func requireProvidedStrategyConflict() async throws {
        strayIdentityManager.reserve(ObjectSnapshotID(10))
        
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(snapshotID: .int(10)),
            ]
        )
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .reservationConflict(.objectSnapshot, .int(10)))) {
            _ = try loader.resolveIdentities(resolution: resolution,
                                             identityStrategy: .requireProvided)
        }

        let resolution2 = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(snapshotID: .int(110), id: .int(10)),
            ]
        )
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .reservationConflict(.object, .int(10)))) {
            _ = try loader.resolveIdentities(resolution: resolution2,
                                             identityStrategy: .requireProvided)
        }

        let resolution3 = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawFrames: [
                RawFrame(id: .int(10)),
            ]
        )
        // .createNew strategy should never raise
        #expect(throws: DesignLoaderError.item(.frames, 0, .reservationConflict(.frame, .int(10)))) {
            _ = try loader.resolveIdentities(resolution: resolution3,
                                             identityStrategy: .requireProvided)
        }
    }
    @Test("ID conflict when requesting from unavailable list (require)")
    func requireProvidedUnavailableObjectID() async throws {
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(id: .int(10)),
            ]
        )
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .reservationConflict(.object, .int(10)))) {
            _ = try loader.resolveIdentities(resolution: resolution,
                                             identityStrategy: .requireProvided,
                                             unavailableIDs: [10])
        }
    }

    @Test("Strategy: preserve or create if reserved")
    func preserveOrCreateStrategy() async throws {
        strayIdentityManager.reserve(ObjectID(999))
        strayIdentityManager.reserve(ObjectID(99))
        strayIdentityManager.reserve(ObjectID(888))

        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(snapshotID: .int(110), id: .int(10)), // Preserve both
                RawSnapshot(snapshotID: .int(999), id: .int(99)), // Create both
                RawSnapshot(snapshotID: .string("snap"), id: .string("object")),
            ],
            rawFrames: [
                RawFrame(id: .int(200)), // Preserve
                RawFrame(id: .int(888)), // Create
                RawFrame(id: .string("frame")),
            ]
        )
        // .createNew strategy should never raise
        let result = try loader.resolveIdentities(resolution: resolution,
                                                  identityStrategy: .preserveOrCreate)
        #expect(result.reserved.count == 3 + 3 + 3) // fr + snap + obj

        #expect(result.rawIDMap.count == 9)
        #expect(result.rawIDMap[.int(110)] == 110)
        #expect(result.rawIDMap[.int(10)] == 10)
        #expect(result.rawIDMap[.int(200)] == 200)

        #expect(result.rawIDMap[.int(999)] != 999)
        #expect(result.rawIDMap[.int(99)] == 99)
        #expect(result.rawIDMap[.int(888)] != 888)

        #expect(result.rawIDMap[.string("snap")] != nil)
        #expect(result.rawIDMap[.string("object")] != nil)

        #expect(result.objectIDs.count == 3)
        #expect(result.objectIDs[0] == 10)
        #expect(result.objectIDs.contains(99))

        #expect(result.snapshotIDs.count == 3)
        #expect(result.snapshotIDs[0] == 110)
        #expect(result.snapshotIDs[1] != 999)

        #expect(result.frameIDs.count == 3)
        #expect(result.frameIDs[0] == 200)
        #expect(result.frameIDs[1] != 888)
    }
    @Test("ID Conflict when not available (preserve or create)")
    func preserveOrCreateWithUnavailableObjectID() async throws {
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(id: .int(10)),
            ]
        )
        let result = try loader.resolveIdentities(resolution: resolution,
                                                  identityStrategy: .preserveOrCreate,
                                                  unavailableIDs: [10])
        #expect(!result.reserved.contains(10))
        #expect(!result.objectIDs.contains(10))
        #expect(result.rawIDMap[.int(10)] != 10)

    }
    @Test("Prevent conflict with request first - create later")
    func reservationOrderingBug() async throws {
        // There was a bug where an ID might have been reserved through regular sequence before
        // an actual ID with the same value was requested later, which resulted in conflict.
        // We need to simulate the situation and make sure it is OK.
        let resolution = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(snapshotID: .int(3)),
                RawSnapshot(snapshotID: nil),
                RawSnapshot(snapshotID: .int(2)),
            ]
        )
        let result = try loader.resolveIdentities(resolution: resolution,
                                                  identityStrategy: .preserveOrCreate)
        #expect(result.snapshotIDs[0] == 3)
        #expect(result.snapshotIDs[1] != 2)
        #expect(result.snapshotIDs[2] == 2)

    }
}

@Suite("Design Loader: snapshot resolution")
struct DesignLoaderSnapshotResolutionTests {
    let strayIdentityManager: IdentityManager
    let loader: DesignLoader
    
    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
        self.strayIdentityManager = IdentityManager()
    }
    
    @Test func empty() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [],
            rawFrames: []
        )
        let identities = try loader.resolveIdentities(resolution: validation,
                                                      identityStrategy: .preserveOrCreate)
        let snapshots = try loader.resolveObjectSnapshots(resolution: validation, identities: identities)
        #expect(snapshots.objectSnapshots.isEmpty)
    }
    
    // TEST: .unknownID for snapshot reference

    @Test("Unknown ID in object snapshot structure")
    func unknownIDinStructure() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(snapshotID: .int(10), id: .int(20),
                            structure: RawStructure("edge", references: [.int(999), .int(999)]))
            ],
        )
        let identities = try loader.resolveIdentities(resolution: validation,
                                                      identityStrategy: .requireProvided)
        
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .unknownID(.int(999)))) {
            _ = try loader.resolveObjectSnapshots(resolution: validation,
                                                  identities: identities)
        }
    }

    @Test("Invalid structural type")
    func invalidStructure() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test",
                            snapshotID: .int(10), id: .int(20),
                            structure: RawStructure("carrot", references: []))
            ],
        )
        let identities = try loader.resolveIdentities(resolution: validation,
                                                      identityStrategy: .requireProvided)
        
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .invalidStructuralType)) {
            _ = try loader.resolveObjectSnapshots(resolution: validation,
                                                  identities: identities)
        }
    }
    @Test("Missing object type name")
    func missingTypeName() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: nil,
                            snapshotID: .int(10), id: .int(20))
            ],
        )
        let identities = try loader.resolveIdentities(resolution: validation,
                                                      identityStrategy: .requireProvided)
        
        #expect(throws: DesignLoaderError.item(.objectSnapshots, 0, .missingObjectType)) {
            _ = try loader.resolveObjectSnapshots(resolution: validation,
                                                  identities: identities)
        }
    }
    @Test("Name from Object ID (compatibility)")
    func nameFromObjectID() async throws {
        let loader = DesignLoader(metamodel: TestMetamodel, options: .useIDAsNameAttribute)

        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test",
                            snapshotID: .int(10), id: .string("rabbit"))
            ],
        )
        let identities = try loader.resolveIdentities(resolution: validation,
                                                      identityStrategy: .requireProvided)
        
        let snapshots = try loader.resolveObjectSnapshots(resolution: validation,
                                                          identities: identities)
        #expect(snapshots.objectSnapshots[0].typeName == "Test")
        #expect(snapshots.objectSnapshots[0].snapshotID == ObjectSnapshotID(10))
        #expect(snapshots.objectSnapshots[0].attributes?["name"] == Variant("rabbit"))
    }

    @Test("Correct Resolve")
    func correctResolve() async throws {
        let validation = DesignLoader.ValidationResolution(
            identityManager: strayIdentityManager,
            rawSnapshots: [
                RawSnapshot(typeName: "Test",
                            snapshotID: .int(100), id: .int(10),
                            structure: RawStructure("node"),
                            parent: .int(20),
                            attributes: ["name": Variant("rabbit")]),
                RawSnapshot(typeName: "Test",
                            snapshotID: .int(200), id: .int(20),
                            structure: RawStructure("edge", references: [.int(20), .int(20)])),
                RawSnapshot(typeName: "Test",
                            snapshotID: .int(300), id: .int(30),
                            structure: RawStructure("unstructured")),
            ],
        )
        let identities = try loader.resolveIdentities(resolution: validation,
                                                      identityStrategy: .requireProvided)
        
        let result = try loader.resolveObjectSnapshots(resolution: validation,
                                                       identities: identities)
        let snapshots = result.objectSnapshots
        #expect(snapshots.count == 3)
        #expect(snapshots[0].typeName == "Test")
        #expect(snapshots[0].snapshotID == ObjectSnapshotID(100))
        #expect(snapshots[0].objectID == ObjectID(10))
        #expect(snapshots[0].structureType == .node)
        #expect(snapshots[0].structureReferences == [])
        #expect(snapshots[0].parent == ObjectID(20))
        #expect(snapshots[0].attributes == ["name": Variant("rabbit")])
        
        #expect(snapshots[1].snapshotID == ObjectSnapshotID(200))
        #expect(snapshots[1].objectID == ObjectID(20))
        #expect(snapshots[1].structureType == .edge)
        #expect(snapshots[1].structureReferences == [ObjectID(20), ObjectID(20)])

        #expect(snapshots[2].snapshotID == ObjectSnapshotID(300))
        #expect(snapshots[2].objectID == ObjectID(30))
        #expect(snapshots[2].structureType == .unstructured)
        #expect(snapshots[2].structureReferences == [])
    }


    // TODO: [TEST] .unknownID for snapshot parent

}

@Suite("Design Loader: integration tests")
struct DesignLoaderIntegrationTests {
    let loader: DesignLoader

    init() {
        self.loader = DesignLoader(metamodel: TestMetamodel)
    }

    @Test("Load complete design with various object types and hierarchy")
    func loadCompleteDesign() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11), structure: RawStructure("node")),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(102), id: .int(12), structure: RawStructure("node")),
                RawSnapshot(typeName: "TestEdge", snapshotID: .int(103), id: .int(13),
                            structure: RawStructure("edge", references: [.int(11), .int(12)])),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(104), id: .int(14), parent: .int(10)),
            ],
            frames: [
                RawFrame(snapshots: [.int(100), .int(101), .int(102), .int(103), .int(104)])
            ]
        )
        let design = try loader.load(raw)

        // Verify unstructured parent with child
        let o0 = try #require(design.snapshot(ObjectSnapshotID(100)))
        #expect(o0.objectID == ObjectID(10))
        #expect(o0.snapshotID == ObjectSnapshotID(100))
        #expect(o0.structure == .unstructured)
        #expect(o0.parent == nil)
        #expect(Array(o0.children) == [ObjectID(14)])

        // Verify first node
        let o1 = try #require(design.snapshot(ObjectSnapshotID(101)))
        #expect(o1.objectID == ObjectID(11))
        #expect(o1.snapshotID == ObjectSnapshotID(101))
        #expect(o1.structure == .node)
        #expect(o1.parent == nil)
        #expect(o1.children.isEmpty == true)

        // Verify second node
        let o2 = try #require(design.snapshot(ObjectSnapshotID(102)))
        #expect(o2.objectID == ObjectID(12))
        #expect(o2.snapshotID == ObjectSnapshotID(102))
        #expect(o2.structure == .node)
        #expect(o2.parent == nil)
        #expect(o2.children.isEmpty == true)

        // Verify edge connecting the two nodes
        let o3 = try #require(design.snapshot(ObjectSnapshotID(103)))
        #expect(o3.objectID == ObjectID(13))
        #expect(o3.snapshotID == ObjectSnapshotID(103))
        #expect(o3.structure == .edge(ObjectID(11), ObjectID(12)))
        #expect(o3.parent == nil)
        #expect(o3.children.isEmpty == true)

        // Verify child of first object
        let o4 = try #require(design.snapshot(ObjectSnapshotID(104)))
        #expect(o4.objectID == ObjectID(14))
        #expect(o4.snapshotID == ObjectSnapshotID(104))
        #expect(o4.structure == .unstructured)
        #expect(o4.parent == ObjectID(10))
        #expect(o4.children.isEmpty == true)
    }

    @Test("Identity manager uses loaded IDs")
    func identityManagerUsesLoadedIDs() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(100)])
            ]
        )
        let design = try loader.load(raw)
        let frame = try #require(design.frames.first)
        let obj = try #require(design.snapshot(ObjectSnapshotID(100)))

        #expect(design.identityManager.isUsed(frame.id))
        #expect(design.identityManager.isUsed(obj.id))
        #expect(design.identityManager.isUsed(obj.objectID))
        #expect(design.identityManager.used.count == 3)

        // NOTE: After loading, all reserved IDs should be moved to used
        // If this fails, it means some IDs remain in reserved state
        #expect(design.identityManager.reserved.count == 0)
    }

    @Test("Load design with system lists and references")
    func loadSystemRefsAndListsUndoRedo() async throws {
        let raw = RawDesign(
            snapshots: [],
            frames: [
                RawFrame(id: .int(100), snapshots: []), // current frame
                RawFrame(id: .int(101), snapshots: []), // undo 1
                RawFrame(id: .int(102), snapshots: []), // undo 2
                RawFrame(id: .int(103), snapshots: []), // redo 1
            ],
            systemReferences: [
                RawNamedReference("current_frame", type: "frame", id: .int(100))
            ],
            systemLists: [
                RawNamedList("undo", itemType: "frame", ids: [.int(101), .int(102)]),
                RawNamedList("redo", itemType: "frame", ids: [.int(103)]),
            ]
        )
        let design = try loader.load(raw)

        #expect(design.currentFrameID == FrameID(100))
        #expect(design.undoList == [FrameID(101), FrameID(102)])
        #expect(design.redoList == [FrameID(103)])
    }

    @Test("Load design without system references")
    func loadWithoutSystemReferences() async throws {
        // Valid: no current frame and no history lists
        let raw = RawDesign(
            snapshots: [],
            frames: [
                RawFrame(id: .int(100), snapshots: []),
            ]
        )
        let design = try loader.load(raw)

        #expect(design.currentFrameID == nil)
        #expect(design.undoList.isEmpty)
        #expect(design.redoList.isEmpty)
    }

    @Test("Load design with user named frame")
    func loadUserReferenceNamedFrame() async throws {
        let raw = RawDesign(
            snapshots: [],
            frames: [
                RawFrame(id: .int(100), snapshots: []),
                RawFrame(id: .int(101), snapshots: []),
            ],
            userReferences: [
                RawNamedReference("my_special_frame", type: "frame", id: .int(101))
            ]
        )
        let design = try loader.load(raw)

        let namedFrame = design.frame(name: "my_special_frame")
        #expect(namedFrame?.id == FrameID(101))
    }

    @Test("Load empty design")
    func loadEmptyDesign() async throws {
        let raw = RawDesign()
        let design = try loader.load(raw)

        #expect(design.frames.isEmpty)
        #expect(design.currentFrameID == nil)
        #expect(design.undoList.isEmpty)
        #expect(design.redoList.isEmpty)
    }

    @Test("Load design with snapshots but no frames")
    func loadSnapshotsWithoutFrames() async throws {
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11)),
            ]
        )
        let design = try loader.load(raw)

        // Snapshots without frames are not actually loaded into the design
        // (they go through resolution pipeline but aren't inserted)
        #expect(design.frames.isEmpty)
        #expect(design.snapshot(ObjectSnapshotID(100)) == nil)
        #expect(design.snapshot(ObjectSnapshotID(101)) == nil)
    }

    @Test("Error: circular parent-child relationship")
    func errorCircularParentChild() async throws {
        // Snapshot 10 is parent of 20, and 20 is parent of 10 - circular!
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10), parent: .int(20)),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(200), id: .int(20), parent: .int(10)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(100), .int(200)])
            ]
        )

        #expect(throws: DesignLoaderError.item(.frames, 0, .brokenStructuralIntegrity(.parentChildCycle))) {
            _ = try loader.load(raw)
        }
    }

    @Test("Error: self-referencing parent")
    func errorSelfReferencingParent() async throws {
        // Snapshot 10 is its own parent
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10), parent: .int(10)),
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(100)])
            ]
        )

        #expect(throws: DesignLoaderError.item(.frames, 0, .brokenStructuralIntegrity(.parentChildCycle))) {
            _ = try loader.load(raw)
        }
    }

    @Test("Error: duplicate object in frame")
    func errorDuplicateObjectInFrame() async throws {
        // Frame contains two snapshots of the same object (ID 10)
        let raw = RawDesign(
            snapshots: [
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(100), id: .int(10)),
                RawSnapshot(typeName: "TestPlain", snapshotID: .int(200), id: .int(10)), // same object ID!
            ],
            frames: [
                RawFrame(id: .int(1000), snapshots: [.int(100), .int(200)])
            ]
        )

        #expect(throws: DesignLoaderError.item(.frames, 0, .duplicateObject(.int(200)))) {
            _ = try loader.load(raw)
        }
    }

    @Test("Error: missing current frame when history exists")
    func errorMissingCurrentFrameWithHistory() async throws {
        // Invalid: has undo list but no current frame
        let raw = RawDesign(
            snapshots: [],
            frames: [
                RawFrame(id: .int(100), snapshots: []),
                RawFrame(id: .int(101), snapshots: []),
            ],
            systemLists: [
                RawNamedList("undo", itemType: "frame", ids: [.int(101)]),
            ]
        )

        #expect(throws: DesignLoaderError.design(.missingCurrentFrame)) {
            _ = try loader.load(raw)
        }
    }
}

//
//    // MARK: - Load Into -
//    
//    @Test func loadIntoHasChanges() async throws {
//        let trans = design.createFrame()
//        let raw = RawSnapshot(typeName: "TestPlain")
//        try loader.load([raw], into: trans)
//        
//        #expect(trans.snapshots.count == 1)
//        #expect(trans.hasChanges)
//    }
//    
//    @Test func loadIntoMultipleTimes() async throws {
//        let trans = design.createFrame()
//        let raw = RawSnapshot(typeName: "TestPlain")
//        try loader.load([raw], into: trans)
//        try loader.load([raw], into: trans)
//        
//        try #require(trans.snapshots.count == 2)
//        
//        #expect(trans.snapshots[0].snapshotID != trans.snapshots[1].snapshotID)
//        #expect(trans.snapshots[0].id != trans.snapshots[1].id)
//    }
//    @Test func loadIntoReferences() async throws {
//        let trans = design.createFrame()
//        let node1 = RawSnapshot(typeName: "TestNode", id: .int(10))
//        let node2 = RawSnapshot(typeName: "TestNode", id: .int(20))
//        let edge = RawSnapshot(typeName: "TestEdge", id: .int(30), structure: RawStructure(origin: .int(10), target: .int(20)))
//        try loader.load([node1, node2, edge], into: trans)
//        
//        try #require(trans.snapshots.count == 3)
//        let createdEdge = try #require(trans.snapshots.first (where: { $0.structure.type == .edge }))
//        
//        if case let .edge(origin, target) = createdEdge.structure {
//            #expect(origin != target)
//            #expect(trans.contains(origin))
//            #expect(trans.contains(target))
//        }
//    }
//    @Test func loadIntoBrokenReference() async throws {
//        let trans = design.createFrame()
//        let edge = RawSnapshot(typeName: "TestEdge", id: .int(30), structure: RawStructure(origin: .int(10), target: .int(20)))
//        #expect(throws: DesignLoaderError.snapshotError(0, .unknownObjectID(.int(10)))) {
//            try loader.load([edge], into: trans)
//        }
//    }
//    @Test func importIntoNoCurrentID() async throws {
//        let trans = design.createFrame()
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestPlain")
//            ]
//        )
//        try loader.load(rawDesign, into: trans)
//        
//        #expect(trans.snapshots.count == 1)
//        #expect(trans.hasChanges)
//    }
//    
//    @Test func importIntoInvalidCurrentID() async throws {
//        let trans = design.createFrame()
//        let rawDesign = RawDesign(
//            snapshots: [
//            ],
//            systemReferences: [
//                RawNamedReference("current_frame", type: "frame", id: .int(99))
//            ]
//        )
//        #expect(throws: DesignLoaderError.unknownFrameID(.int(99))) {
//            try loader.load(rawDesign, into: trans)
//        }
//    }
//    @Test func importIntoNoCurrentIDWithMultipleFrames() async throws {
//        let trans = design.createFrame()
//        let rawDesign = RawDesign(
//            snapshots: [
//            ],
//            frames: [
//                RawFrame(),
//                RawFrame()
//            ]
//        )
//        #expect(throws: DesignLoaderError.missingCurrentFrame) {
//            try loader.load(rawDesign, into: trans)
//        }
//    }
//    @Test func importFromCurrentFrame() async throws {
//        let trans = design.createFrame()
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(10)),
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(20)),
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(30)),
//            ],
//            frames: [
//                RawFrame(id: .int(1000), snapshots: [.int(10)]),
//                RawFrame(id: .int(1001), snapshots: [.int(10), .int(20)]),
//            ],
//            systemReferences: [
//                RawNamedReference("current_frame", type: "frame", id: .int(1000))
//            ]
//        )
//        try loader.load(rawDesign, into: trans)
//        #expect(trans.snapshots.count == 1)
//    }
//    
//    @Test func duplicateID() async throws {
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestPlain", id: .string("thing")),
//                RawSnapshot(typeName: "TestPlain", id: .string("thing")),
//            ],
//        )
//        let trans = design.createFrame()
//        #expect(throws: DesignLoaderError.snapshotError(1, .duplicateID(.string("thing")))) {
//            try loader.load(rawDesign.snapshots, into: trans)
//        }
//    }
//    
//    @Test func childrenMismatchNoneToSome() async throws {
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(10), id: .int(100)),
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(20), id: .int(200), parent: .int(100)),
//            ],
//            frames: [
//                RawFrame(id: .int(1000), snapshots: [.int(10)]),
//                RawFrame(id: .int(1001), snapshots: [.int(10), .int(20)]),
//            ],
//            systemReferences: [
//                RawNamedReference("current_frame", type: "frame", id: .int(1000))
//            ]
//        )
//        #expect(throws: DesignLoaderError.frameError(1, .childrenMismatch(0))) {
//            try loader.load(rawDesign)
//        }
//    }
//    @Test func childrenMismatchSomeToNone() async throws {
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(10), id: .int(100)),
//                RawSnapshot(typeName: "TestPlain", snapshotID: .int(20), id: .int(200), parent: .int(100)),
//            ],
//            frames: [
//                RawFrame(id: .int(1000), snapshots: [.int(10), .int(20)]),
//                RawFrame(id: .int(1001), snapshots: [.int(10)]),
//            ],
//            systemReferences: [
//                RawNamedReference("current_frame", type: "frame", id: .int(1000))
//            ]
//        )
//        #expect(throws: DesignLoaderError.frameError(1, .childrenMismatch(0))) {
//            try loader.load(rawDesign)
//        }
//    }
//    
//    @Test func loadCreateIdentity() async throws {
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestNode", snapshotID: .int(100), id: .int(10)),
//            ],
//        )
//        let trans = design.createFrame()
//        try loader.load(rawDesign.snapshots, into: trans, identityStrategy: .createNew)
//        try design.accept(trans)
//        #expect(design.identityManager.reserved.isEmpty)
//        
//        let snapshot = try #require(design.objectSnapshots.first)
//        #expect(snapshot.snapshotID != ObjectSnapshotID(100))
//        #expect(snapshot.objectID != ObjectID(10))
//    }
//    
//    @Test func loadTwiceWithPreserveOrCreate() async throws {
//        let rawDesign = RawDesign(
//            snapshots: [
//                RawSnapshot(typeName: "TestNode", snapshotID: .int(101), id: .int(11), attributes: ["name": "node"]),
//                RawSnapshot(typeName: "TestEdge", snapshotID: .int(102), id: .int(12),
//                            structure: RawStructure(origin: .int(11), target: .int(11)), attributes: ["name": "edge"]),
//                RawSnapshot(typeName: "TestNode", snapshotID: .int(103), id: .int(13), parent: .int(11), attributes: ["name": "child"]),
//            ],
//        )
//        let trans = design.createFrame()
//        try loader.load(rawDesign.snapshots, into: trans, identityStrategy: .preserveOrCreate)
//        let frame = try design.accept(trans)
//        #expect(design.identityManager.reserved.isEmpty)
//        
//        let node1 = try #require(frame.first(where: { $0["name"] == "node"}))
//        let edge1 = try #require(frame.first(where: { $0["name"] == "edge"}))
//        let child1 = try #require(frame.first(where: { $0["name"] == "child"}))
//        #expect(edge1.structure == .edge(node1.objectID, node1.objectID))
//        #expect(child1.parent == node1.objectID)
//        #expect(node1.children == [child1.objectID])
//        
//        let trans2 = design.createFrame(deriving: frame)
//        try loader.load(rawDesign.snapshots, into: trans2, identityStrategy: .preserveOrCreate)
//        
//        let frame2 = try design.accept(trans2)
//        let node2 = try #require(frame2.first(where: { $0["name"] == "node" && $0.objectID != node1.objectID }))
//        let edge2 = try #require(frame2.first(where: { $0["name"] == "edge" && $0.objectID != edge1.objectID }))
//        let child2 = try #require(frame2.first(where: { $0["name"] == "child" && $0.objectID != child1.objectID }))
//        
//        #expect(edge2.structure == .edge(node2.objectID, node2.objectID))
//        #expect(child2.parent == node2.objectID)
//        #expect(node2.children == [child2.objectID])
//    }
//    
//    @Test func simulatedPaste() async throws {
//        let trans1 = design.createFrame()
//        let a = trans1.createNode(TestNodeType, attributes: ["name": "a"])
//        let b = trans1.createNode(TestNodeType, attributes: ["name": "b"])
//        let edge = trans1.createEdge(TestEdgeType, origin: a.objectID, target: b.objectID, attributes: ["name": "edge"])
//        let frame1 = try design.accept(trans1)
//        
//        // Copy
//        let extractor = DesignExtractor()
//        let extract = extractor.extractPruning(objects: [a.objectID, b.objectID, edge.objectID], frame: frame1)
//        let rawDesign = RawDesign(metamodelName: design.metamodel.name,
//                                  metamodelVersion: design.metamodel.version,
//                                  snapshots: extract)
//        // Paste
//        let trans2 = design.createFrame(deriving: frame1)
//        try loader.load(rawDesign.snapshots,
//                        into: trans2,
//                        identityStrategy: .preserveOrCreate)
//        let frame2 = try design.accept(trans2)
//        // Paste the same thing again
//        let trans3 = design.createFrame(deriving: frame2)
//        try loader.load(rawDesign.snapshots,
//                        into: trans3,
//                        identityStrategy: .preserveOrCreate)
//        
//        let frame3 = try design.accept(trans3)
//        
//        #expect(frame3.filter { $0["name"] == "a" }.count == 3)
//        #expect(frame3.filter { $0["name"] == "b" }.count == 3)
//        #expect(frame3.filter { $0["name"] == "edge" }.count == 3)
//    }

