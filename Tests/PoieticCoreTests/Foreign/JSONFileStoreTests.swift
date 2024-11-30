//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/06/2023.
//

import XCTest
@testable import PoieticCore

final class JSONFileStoreTests: XCTestCase {
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
    var db: Design!
    var frame: TransientFrame!
    
    override func setUp() {
        db = Design(metamodel: TestMetamodel)
        frame = db.createFrame()

        let flow = frame.create(TestMetamodel["Flow"]!,
                                structure: .node,
                                attributes: [:],
                                components: [IntegerComponent(value: 10)])
        let source = frame.create(TestMetamodel["Stock"]!,
                                  structure: .node,
                                  attributes: [:],
                                  components: [IntegerComponent(value: 20)])
        let sink = frame.create(TestMetamodel["Stock"]!,
                                structure: .node,
                                attributes: [:],
                                components: [IntegerComponent(value: 30)])
        
        frame.createEdge(TestMetamodel["Arrow"]!, origin: source.id, target: flow.id)
        frame.createEdge(TestMetamodel["Arrow"]!, origin: flow.id, target: sink.id)
        do {
            try db.accept(frame)
        }
        catch {
            fatalError("Failed to accept frame: \(error)")
        }
    }
    
    func testEmpty(){
        XCTAssertEqual(1, 1)
    }

    func testRestore() throws {
//        let tmpURL = temporaryFileURL()
       
//        let writer = try JSONFilePackageWriter(url: tmpURL)
//        db.write(writer)

//        let reader = JSONFilePackageReader(tmpURL)
//        let restored = Design(metamodel=Metamodel,
//                                store=load_store)
//        self.assertEqual(len(list(self.db.snapshots)),
//                         len(list(restored.snapshots)))
//
//        other_frame = restored.frame(self.frame.version)
//
//        for snapshot in self.frame.snapshots:
//            other = other_frame.object(snapshot.id)
//            if snapshot != other:
//                # import pdb; pdb.set_trace()
//                pass
//
//            self.assertEqual(snapshot, other)
//
//        tmpdir.cleanup()

    }
    
}
