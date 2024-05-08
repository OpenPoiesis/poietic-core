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

    // MARK: Save tests
    //
    /**
    Creates a URL for a temporary file on disk. Registers a teardown block to
    delete a file at that URL (if one exists) during test teardown.
    */
    func temporaryFileURL() -> URL {
        let fm = FileManager()
        // Create a URL for an unique file in the system's temporary directory.
        let directory = fm.temporaryDirectory.path
        let filename = UUID().uuidString
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(filename)
        
        // Add a teardown block to delete any file at `fileURL`.
        addTeardownBlock {
            do {
                let fileManager = FileManager.default
                // Check that the file exists before trying to delete it.
                if fileManager.fileExists(atPath: fileURL.path) {
                    // Perform the deletion.
                    try fileManager.removeItem(at: fileURL)
                    // Verify that the file no longer exists after the deletion.
                    XCTAssertFalse(fileManager.fileExists(atPath: fileURL.path))
                }
            } catch {
                // Treat any errors during file deletion as a test failure.
                XCTFail("Error while deleting temporary file: \(error)")
            }
        }
        
        // Return the temporary file URL for use in a test method.
        return fileURL
    }

    func testCreateEmpty() throws {
        let store = try MakeshiftDesignStore(url: temporaryFileURL())
    }
    
}
