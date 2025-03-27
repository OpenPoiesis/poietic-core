//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/04/2024.
//

import XCTest
@testable import PoieticCore

let TestFormatVersion = "0.0.4"

final class MakeshiftStoreTests: XCTestCase {
    // MARK: Load tests
    func testInvalidJSON() throws {
        let data = "invalid".data(using:.utf8)!
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load()){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.dataCorrupted)
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    func testRestoreNoFormatVersion() throws {
        let data = """
                   {
                   }
                   """.data(using:.utf8)!
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load()){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.missingProperty("store_format_version", []))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    func testMissingMetamodel() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)"
                   }
                   """.data(using:.utf8)!
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load()){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.missingProperty("metamodel", []))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    func testEmpty() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": [],
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = MakeshiftDesignStore(data: data)
        XCTAssertNoThrow(try store.load())
    }
    
    func testMalformedCollection() throws {
        let data = """
                   {
                    "store_format_version": "\(TestFormatVersion)",
                    "metamodel": "",
                    "state": {"undoable_frames": [], "redoable_frames": []},
                    "snapshots": 1234,
                    "frames": []
                   }
                   """.data(using:.utf8)!
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load()){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.typeMismatch(["snapshots"]))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    
    func testUnknownObjectType() throws {
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
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load()){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.unknownObjectType("BOO"))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    func testUnknownStructuralType() throws {
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
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load(metamodel: TestMetamodel)){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.invalidStructuralType("boo"))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    func testStructuralTypeMismatch() throws {
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
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load(metamodel: TestMetamodel)){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.structuralTypeMismatch(.node, .edge))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
    func testDuplicateSnapshot() throws {
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
        let store = MakeshiftDesignStore(data: data)
        XCTAssertThrowsError(try store.load(metamodel: TestMetamodel)){ error in
            if let error = error as? PersistentStoreError {
                XCTAssertEqual(error, PersistentStoreError.duplicateSnapshot(ObjectID(2)))
            }
            else {
                XCTFail("Store error expected, got: \(error)")
            }
        }
    }
}
