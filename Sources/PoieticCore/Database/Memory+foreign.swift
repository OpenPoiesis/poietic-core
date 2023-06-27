//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 23/06/2023.
//

import Foundation

enum ForeignInterfaceError: Error {
    case unsupportedVersion(String)
    case unknownStructuralType(String)
    case malformedComponents
    case malformedMainRecord
    
    
    case typeMismatchError(ForeignValue, ValueType)
}

extension ObjectMemory {
//    convenience init(_ reader: StoreReader,
//                     metamodel: Metamodel.Type) throws {
//        // 0. Read info
//        let info = reader.info()
//        
//        if info.formatVersion != "0.0.1" {
//            throw ForeignInterfaceError.unsupportedVersion(info.formatVersion)
//        }
//        
//        // 1. Read Snapshots
//        // ----------------------------------------------------------------
//        let records = reader.fetchAll(type: "snapshots")
//        for record in records {
//            let snapshot = try ObjectSnapshot(fromRecord: record,
//                                              metamodel: metamodel)
//        }
//    }
    
    func createSnapshot(record: ExtendedForeignRecord,
                        metamodel: Metamodel.Type) throws -> ObjectSnapshot {
        // TODO: This should include the snapshot into the list of snapshots
        // TODO: Handle wrong IDs
        let id: ObjectID = try record.main.IDValue(for: "object_id")
        let snapshotID: SnapshotID = try record.main.IDValue(for: "snapshot_id")

        let type: ObjectType?
        
        if let typeName = try record.main.stringValueIfPresent(for: "type") {
            if let objectType = metamodel.objectType(name: typeName) {
                type = objectType
            }
            else {
                fatalError("Unknown object type: \(typeName)")
            }
        }
        else {
            type = nil
        }

        var components: [any Component] = []
        
        for (name, compRecord) in record.components {
            let type: Component.Type = persistableComponent(name: name)!
            let component = try type.init(record: compRecord)
            components.append(component)
        }

        let snapshot: ObjectSnapshot
        
        let structuralTypeName = try record.main.stringValue(for: "structural_type")
        switch structuralTypeName {
        case "object":
            snapshot = ObjectSnapshot(id: id,
                                      snapshotID: snapshotID,
                                      type: type,
                                      components: components)
        case "node":
            snapshot = Node(id: id,
                            snapshotID: snapshotID,
                            type: type,
                            components: components)
        case "edge":
            let origin: ObjectID = try record.main.IDValue(for: "origin")
            let target: ObjectID = try record.main.IDValue(for: "target")
            snapshot = Edge(id: id,
                            snapshotID: snapshotID,
                            type: type,
                            origin: origin,
                            target: target,
                            components: components)
        default:
            throw ForeignInterfaceError.unknownStructuralType(structuralTypeName)
        }

        return snapshot
    }
    
    // TODO: Use Store/Writer protocol
    func write(_ writer: StoreWriter) {
        /*
         
         Structure:
         
         - /ROOT/
            - snapshots/
            - framesets/
            - frames/
            - components/
         
         */
        // TODO: This is preliminary implementation, which is not fully normalized
        // Collections to be written
        //
        var framesetsOut: [ForeignRecord] = []
        var framesOut: [ForeignRecord] = []
        var snapshotsOut: [ForeignRecord] = []
        var componentsOut: [ExtendedForeignRecord] = []
        
        // 1. Write Snapshots
        // ----------------------------------------------------------------
        
        for snapshot in snapshots {
            let record = snapshot.asForeignRecord()
            snapshotsOut.append(record)
            var snapshotComponents: [String:ForeignRecord] = [:]

            for component in snapshot.components {
                let componentRecord = component.foreignRecord()
                snapshotComponents[component.componentName] = componentRecord
            }
            
            let extended = ExtendedForeignRecord(main: record,
                                                 components: snapshotComponents)
            componentsOut.append(extended)
        }

        // 2. Write Stable Frames
        // ----------------------------------------------------------------
        // Unstable frames should not be persisted.
        
        for frame in frames {
            let ids: [SnapshotID] = frame.snapshots.map { $0.snapshotID }
            let record: ForeignRecord = ForeignRecord([
                "frame_id": ForeignValue(frame.id),
                "snapshots": ForeignValue(ids: ids),
            ])
            framesOut.append(record)
        }
        // 3. Write Framesets
        // ----------------------------------------------------------------
        // We have only one frameset at the moment - undo history
        // TODO: What about current frame?
        let historyRecord = ForeignRecord([
            "name": "undo",
            "frames": ForeignValue(ids: undoableFrames)
        ])
        framesetsOut.append(historyRecord)
        
        
        // Final. Write output
        // ----------------------------------------------------------------
        writer.replaceRecords(type: "snapshots", records: snapshotsOut)
        writer.replaceRecords(type: "frames", records: framesOut)
        writer.replaceRecords(type: "framesets", records: framesetsOut)
        writer.replaceRecords(type: "components", records: framesetsOut)
    }

}
