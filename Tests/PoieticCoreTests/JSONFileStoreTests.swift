//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 19/06/2023.
//

import XCTest
@testable import PoieticCore

class TestPersistentRecord: XCTestCase {
    // TODO: This seems to be testing some obsolete functionality or a functionality that has been moved
    var memory: ObjectMemory!

    override func setUp() {
        self.memory = ObjectMemory(metamodel: TestMetamodel.self)
    }

    func testFromRecord() throws {
        let info = ForeignRecord([
            "type": Variant("Stock"),
            "id": Variant(10),
            "snapshot_id": Variant(20),
        ])

        let record = ObjectRecord(info: info, attributes: ForeignRecord())
        
        let obj: ObjectSnapshot = try memory.createSnapshot(record)
        
        XCTAssertEqual(obj.id, 10)
        XCTAssertEqual(obj.snapshotID, 20)
        XCTAssertEqual(obj.structure, .node)
        XCTAssertIdentical(obj.type, Metamodel.Stock)
        
        XCTAssertNotNil(memory.allSnapshots.first(where: {$0.snapshotID == obj.snapshotID}))
    }
}

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
    var db: ObjectMemory!
    var frame: MutableFrame!
    var graph: MutableGraph!
    
    override func setUp() {
        db = ObjectMemory()
        frame = db.createFrame()

        let flow = frame.createNode(Metamodel.Flow,
                                    name: nil,
                                    attributes: [:],
                                    components: [IntegerComponent(value: 10)])
        let source = frame.createNode(Metamodel.Stock,
                                      name: nil,
                                      attributes: [:],
                                      components: [IntegerComponent(value: 20)])
        let sink = frame.createNode(Metamodel.Stock,
                                    name:nil,
                                    attributes: [:],
                                    components: [IntegerComponent(value: 30)])
        
        frame.createEdge(Metamodel.Arrow,
                         origin: source,
                         target: flow,
                         attributes: [:],
                         components: [])
        frame.createEdge(Metamodel.Arrow,
                         origin: flow,
                         target: sink,
                         attributes: [:],
                         components: [])
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
//        let restored = ObjectMemory(metamodel=Metamodel,
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
