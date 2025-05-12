//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/04/2024.
//

import Testing
@testable import PoieticCore

let TestFormatVersion = "0.0.4"

@Suite struct MakeshiftStoreTests {
    // MARK: Load tests
    @Test func testInvalidJSON() throws {
        let data = "invalid".data(using:.utf8)!
        let store = DesignStore(data: data)
        #expect(throws: DesignStoreError.dataCorrupted) {
            try store.load()
        }
    }
    @Test func testRestoreNoFormatVersion() throws {
        let data = """
                   {
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        #expect(throws: DesignStoreError.missingProperty("store_format_version", [])) {
            try store.load()
        }
    }
    @Test func testMissingMetamodel() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)"
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        #expect(throws: DesignStoreError.missingProperty("metamodel", [])) {
            try store.load()
        }
    }
    @Test func testEmpty() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        _ = try store.load()
    }
    
    @Test func testMalformedCollection() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": 1234,
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        #expect(throws: DesignStoreError.typeMismatch(["snapshots"])) {
            try store.load()
        }
    }
    
    @Test func testUnknownObjectType() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [{
                        "id": 1,
                        "snapshot_id": 2,
                        "type": "BOO",
                        "structural_type": "node",
                        "attributes": {}
                    }
                    ],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        
        #expect(throws: DesignStoreError.unknownObjectType("BOO")) {
            try store.load()
        }
        
    }
    @Test func testUnknownStructuralType() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [{
                        "id": 1,
                        "snapshot_id": 2,
                        "type": "Stock",
                        "structural_type": "boo",
                        "attributes": {}
                    }
                    ],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        
        #expect(throws: DesignStoreError.invalidStructuralType("boo")) {
            try store.load(metamodel: TestMetamodel)
        }
    }
    @Test func testStructuralTypeMismatch() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [{
                        "id": 1,
                        "snapshot_id": 2,
                        "type": "Stock",
                        "structural_type": "edge",
                        "attributes": {}
                    }
                    ],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        
        #expect(throws: DesignStoreError.structuralTypeMismatch(.node, .edge)) {
            try store.load(metamodel: TestMetamodel)
        }
    }
    @Test func testDuplicateSnapshot() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [{
                        "id": 1,
                        "snapshot_id": 2,
                        "type": "Stock",
                        "structural_type": "node",
                        "attributes": {}
                    },
                    {
                        "id": 1,
                        "snapshot_id": 2,
                        "type": "Stock",
                        "structural_type": "node",
                        "attributes": {}
                    }
                    ],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        
        #expect(throws: DesignStoreError.duplicateSnapshot(ObjectID(2))) {
            try store.load(metamodel: TestMetamodel)
        }
    }
    
    @Test func testNamedFrame() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [],
                    "frames": [{"id": 100, "snapshots": []}],
                    "named_frames": {"app": 100}
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        let design = try store.load()
        #expect(design.frame(name: "app")?.id == 100)
    }
    @Test func testNamedFrameUndoConflict() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": [], "current_frame": 100},
                    "snapshots": [],
                    "frames": [{"id": 100, "snapshots": []}],
                    "named_frames": {"app": 100}
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        #expect(throws: DesignStoreError.illegalFrameAssignment(ObjectID(100))) {
            try store.load(metamodel: TestMetamodel)
        }
    }
    @Test func testRefCount() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [{
                        "id": 1,
                        "snapshot_id": 20,
                        "type": "Unstructured",
                        "structural_type": "unstructured",
                        "attributes": {}
                    }
                    ],
                    "frames": [
                        {"id": 100, "snapshots": [20]},
                        {"id": 200, "snapshots": [20]}
                    ]
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        let design = try store.load(metamodel: TestMetamodel)
        let snapshot = try #require(design.snapshot(ObjectID(20)))
        #expect(design.referenceCount(snapshot.snapshotID) == 2)
    }

}
