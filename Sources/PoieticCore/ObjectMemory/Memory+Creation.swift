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
    ///     - structure: Structural component of the new object that must match the object type.
    ///     - initialized: If set to `false` then the object is left uninitialised.
    ///       The Caller must finish initialisation and mark the snapshot
    ///       initialised before inserting it to a frame.
    ///
    /// The `structuralReferences` list must contain:
    ///
    /// - no references for ``StructuralType/unstructured`` and ``StructuralType/node``
    /// - two references for ``StructuralType/edge``: first for edge's origin,
    ///   second for edge's target.
    ///
    public func createSnapshot(_ type: ObjectType,
                               id: ObjectID? = nil,
                               snapshotID: SnapshotID? = nil,
                               components: [any Component]=[],
                               structure: StructuralComponent? = nil,
                               initialized: Bool = true) -> ObjectSnapshot {
        // TODO: Check for existence and register with list of all snapshots.
        // TODO: This should include the snapshot into the list of snapshots.
        // TODO: Handle wrong IDs.
        let actualID = allocateID(proposed: id)
        let actualSnapshotID = allocateID(proposed: snapshotID)

        let actualStructure: StructuralComponent
        
        switch type.structuralType {
        case .unstructured:
            precondition(structure == nil || structure == .unstructured,
                         "Structural component mismatch for type \(type.name). Got: \(structure!.type) expected: \(type.structuralType)")
            actualStructure = .unstructured
        case .node:
            precondition(structure == nil || structure == .node,
                         "Structural component mismatch for type \(type.name). Got: \(structure!.type) expected: \(type.structuralType)")
            actualStructure = .node
        case .edge:
            guard let structure else {
                fatalError("Structural component of type `edge` is required to be provided for type \(type.name).")
            }
            
            precondition(structure.type == .edge,
                         "Structural component mismatch for type \(type.name). Got: \(structure.type) expected: \(type.structuralType)")

            actualStructure = structure
        }

        let snapshot = ObjectSnapshot(id: actualID,
                                      snapshotID: actualSnapshotID,
                                      type: type,
                                      structure: actualStructure,
                                      components: components)

        if initialized {
            snapshot.makeInitialized()
        }
        return snapshot
    }
    /// Create a new unstructured snapshot.
    ///
    /// Create a new object snapshot that will be unstructured but open.
    /// The structure might be changed by the caller.
    ///
    /// The returned snapshot is unstable and must be made stable before
    /// assigned to a frame.
    ///
    public func allocateUnstructuredSnapshot(_ objectType: ObjectType,
                                 id: ObjectID? = nil,
                                 snapshotID: SnapshotID? = nil) -> ObjectSnapshot {
        // TODO: Test for existence of given snapshotID
        let actualID: ObjectID = allocateID(proposed: id)
        let actualSnapshotID: SnapshotID = allocateID(proposed: snapshotID)

        let snapshot = ObjectSnapshot(id: actualID,
                                      snapshotID: actualSnapshotID,
                                      type: objectType,
                                      structure: .unstructured)
        return snapshot
    }
}
