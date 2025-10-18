//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/04/2024.
//

// TODO: This code is from the prototype phase. Remove once fully replaced with new raw design loading/writing.

import Testing
@testable import PoieticCore

let TestFormatVersion = "0.0.4"

@Suite struct MakeshiftStoreTests {
    @Test func testInvalidJSON() throws {
        let data = "invalid".data(using:.utf8)!
        let store = DesignStore(data: data)
        #expect {
            try store.load()
        }
        throws: {
            guard let error = $0 as? DesignStoreError,
                  case .readingError(let readingError) = error,
                  case .dataCorrupted(_) = readingError else {
                return false
            }
            return true
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
        #expect(throws: DesignStoreError.readingError(.typeMismatch("array", ["snapshots"]))) {
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
                        "type": "UNKNOWN",
                        "structural_type": "node",
                        "attributes": {}
                    }
                    ],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = DesignStore(data: data)
        
        #expect(throws: DesignStoreError.loadingError(.snapshotError(0, .unknownObjectType("UNKNOWN")))) {
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
        
        #expect(throws: DesignStoreError.loadingError(.snapshotError(0, .invalidStructuralType))) {
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
        
        #expect(throws: DesignStoreError.loadingError(.snapshotError(0, .invalidStructuralType))) {
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
        
        #expect(throws: DesignStoreError.loadingError(.snapshotError(1, .identityError(.duplicateID)))) {
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
        let snapshot = try #require(design.snapshot(ObjectSnapshotID(20)))
        #expect(design.referenceCount(snapshot.snapshotID) == 2)
    }

}
