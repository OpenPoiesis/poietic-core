//
//  Design+Creation.swift
//
//
//  Created by Stefan Urbanek on 21/08/2023.
//

extension Design {
    /// Designated function to create snapshots in the design.
    ///
    /// - Parameters:
    ///     - id: Proposed object ID. If not provided, one will be generated.
    ///     - snapshotID: Proposed snapshot ID. If not provided, one will be generated.
    ///     - type: Object type.
    ///     - attributes: Attribute dictionary to be used for object
    ///       initialization.
    ///     - parent: Optional parent object in the hierarchy of objects.
    ///     - components: List of components to be set for the newly created object.
    ///     - structure: Structural component of the new object that must match
    ///       the object type.
    ///     - state: Initial state of the object snapshot.
    ///
    /// - Note: Attributes are not checked according to the object type during
    ///   object creation. The object is not yet required to satisfy any
    ///   constraints.
    /// - Note: Existence of the parent is not verified, it will be during the
    ///   frame insertion.
    ///
    /// - SeeAlso: ``TransientFrame/insert(_:)``
    /// - Precondition: If `id` or `snapshotID` is provided, it must not exist
    ///   in the design.
    /// - Precondition: `structure` must match ``ObjectType/structuralType``.
    ///
    public func createSnapshot(_ type: ObjectType,
                               id: ObjectID? = nil,
                               snapshotID: SnapshotID? = nil,
                               structure: StructuralComponent? = nil,
                               parent: ObjectID? = nil,
                               attributes: [String:Variant]=[:],
                               components: [any Component]=[],
                               state: VersionState = .stable) -> ObjectSnapshot {
        let actualID = allocateID(required: id)
        let actualSnapshotID = allocateID(required: snapshotID)

        precondition(_allSnapshots[actualSnapshotID] == nil,
                     "Snapshot with snapshot ID \(actualSnapshotID) already exists.")

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
        var actualAttributes = attributes
        
        // Add required components as described by the object type.
        //
        for attribute in type.attributes {
            if actualAttributes[attribute.name] == nil {
                actualAttributes[attribute.name] = attribute.defaultValue
            }
        }

        let snapshot = ObjectSnapshot(id: actualID,
                                      snapshotID: actualSnapshotID,
                                      type: type,
                                      structure: actualStructure,
                                      parent: parent,
                                      attributes: actualAttributes,
                                      components: components)

        snapshot.state = state
        self._allSnapshots[actualSnapshotID] = snapshot
        
        return snapshot
    }
    
    /// Create a new snapshot version
    ///
    public func deriveSnapshot(_ originalID: SnapshotID) -> ObjectSnapshot {
        guard let original = _allSnapshots[originalID] else {
            fatalError("Trying to derive a snapshot (\(originalID)) that does not belong to a design")

        }

        let derivedSnapshotID: SnapshotID = allocateID()
        let derived = ObjectSnapshot(id: original.id,
                                     snapshotID: derivedSnapshotID,
                                     type: original.type,
                                     structure: original.structure)
        derived.attributes = original.attributes
        derived.components = original.components
        derived.children = original.children
        derived.parent = original.parent
        return derived
    }
}
