//
//  Memory+Creation.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

extension ObjectMemory {
    /// Designated function to create snapshots in the memory.
    ///
    /// - Parameters:
    ///     - id: Proposed object ID. If not provided, one will be generated.
    ///     - snapshotID: Proposed snapshot ID. If not provided, one will be generated.
    ///     - type: Object type.
    ///     - components: List of components to be set for the newly created object.
    ///     - structuralReferences: List of object references related to the structural object type.
    ///     - uninitialized: Leave the object uninitialised. Caller must make the object
    ///       initialised before inserting it to a frame.
    ///
    /// The `structuralReferences` list must contain:
    ///
    /// - no references for ``StructuralType/object`` and ``StructuralType/node``
    /// - two references for ``StructuralType/edge``: first for edge's origin,
    ///   second for edge's target.
    ///
    public func createSnapshot(_ type: ObjectType,
                               id: ObjectID? = nil,
                               snapshotID: SnapshotID? = nil,
                               components: [any Component]=[],
                               structuralReferences: [ObjectID]=[],
                               uninitialized: Bool = false) -> ObjectSnapshot {
        // TODO: Check for existence and register with list of all snapshots.
        // TODO: This should include the snapshot into the list of snapshots.
        // TODO: Handle wrong IDs.
        let actualID = allocateID(proposed: id)
        let actualSnapshotID = allocateID(proposed: snapshotID)

        let snapshot: ObjectSnapshot
        
        switch type.structuralType {
        case .object:
            precondition(structuralReferences.isEmpty,
                         "Structural references provided for a structural type 'object' without references.")
            snapshot = ObjectSnapshot(id: actualID,
                                      snapshotID: actualSnapshotID,
                                      type: type,
                                      components: components)
        case .node:
            precondition(structuralReferences.isEmpty,
                         "Structural references provided for a structural type 'node' without references.")
            snapshot = Node(id: actualID,
                            snapshotID: actualSnapshotID,
                            type: type,
                            components: components)
        case .edge:
            precondition(structuralReferences.count == 2,
                         "Wrong number (\(structuralReferences.count) of structural references provided for a structural type 'edge', expected exactly two.")
            let origin = structuralReferences[0]
            let target = structuralReferences[1]

            snapshot = Edge(id: actualID,
                            snapshotID: actualSnapshotID,
                            type: type,
                            origin: origin,
                            target: target,
                            components: components)
        }

        if !uninitialized {
            snapshot.state = .transient
        }
        return snapshot
    }
    
}
