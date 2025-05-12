//
//  AppendingTransaction.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 05/05/2025.
//

// FIXME: [WIP] Do we need this to be public?
public enum TransactionError: Error, Equatable {
    case brokenStructuralIntegrity(StructuralIntegrityError)
    case duplicateFrame(ObjectID)
    case duplicateSnapshot(ObjectID)
}

/// Transaction describing an additive change to the design.
///
/// The transaction contains frames and objects that are added to the design. Typical user-facing
/// operation using this kind of transaction is import from a file or paste from pasteboard.
///
class AppendingTransaction {
    let design: Design
    var frames: [DesignFrame] = []
    var snapshots: SnapshotStorage = SnapshotStorage()
    
    init(_ design: Design) {
        self.design = design
    }
    
    func insert(_ snapshot: DesignObject) {
        // FIXME: [WIP] Insert only
        snapshots.insertOrRetain(snapshot)
    }

    func insert(frame: DesignFrame) {
        frames.append(frame)
        for snapshot in frame.snapshots {
            snapshots.insertOrRetain(snapshot)
        }
    }
}


// TODO: [WIP] What to do with current frame?
extension Design {
    func accept(appending trans: AppendingTransaction) throws (TransactionError) {
        precondition(trans.design === self)
        
        // 1. Validate
        for frame in trans.frames {
            guard !contains(stableFrame: frame.id) else {
                throw .duplicateFrame(frame.id)
            }
            do {
                try frame.validateStructure()
            }
            catch {
                throw .brokenStructuralIntegrity(error)
            }
        }
        for snapshot in trans.snapshots.snapshots {
            guard !contains(snapshot: snapshot.snapshotID) else {
                throw .duplicateSnapshot(snapshot.snapshotID)
            }
        }
        // 2. Insert
        for frame in trans.frames {
            _unsafeInsert(frame)
        }
    }
}
