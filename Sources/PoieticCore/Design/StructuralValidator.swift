//
//  StructuralValidator.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 06/11/2025.
//

/// Namespace for snapshot and frame validation methods.
///
public struct StructuralValidator {
    /// Validates that snapshot's structural references within a context of a frame.
    ///
    /// Can be used to check whether the snapshot can be added to a frame.
    ///
    /// What is validated:
    ///
    /// - Parent exist in the frame.
    /// - Children exist in the frame.
    /// - If it is an edge: whether origin and target exist in the frame and are of type
    ///   ``StructuralType/node``.
    /// - If it is an ordered set: whether the owner and all IDs exist in the frame.
    ///
    public static func validate(_ object: some ObjectProtocol, in frame: some Frame)
    throws (StructuralIntegrityError) {
        switch object.structure {
        case .unstructured: break // Nothing to validate.
        case .node: break // Nothing to validate.
        case let .edge(originID, targetID):
            guard let origin = frame[originID],
                  let target = frame[targetID]
            else {
                throw .brokenStructureReference
            }
            guard origin.structure == .node && target.structure == .node else {
                throw .edgeEndpointNotANode
            }
        case let .orderedSet(owner, ids):
            guard frame.contains(owner) && ids.allSatisfy({frame.contains($0)}) else {
                throw .brokenStructureReference
            }
        }

        for childID in object.children {
            guard let child = frame[childID] else {
                throw .brokenChild
            }
            guard child.parent == object.objectID else {
                throw .parentChildMismatch
            }
        }

        if let parentID = object.parent {
            guard let parent = frame[parentID] else {
                throw .brokenParent
            }
            
            guard parent.children.contains(object.objectID) else {
                throw .parentChildMismatch
            }
        }
    }

    /// Return a list of objects that the provided object refers to and
    /// that do not exist within the frame.
    ///
    /// Frame with broken references can not be made stable and accepted
    /// by the design.
    ///
    /// The following references from the snapshot are being considered:
    ///
    /// - If the structure type is an edge (``Structure/edge(_:_:)``)
    ///   then the origin and target is considered.
    /// - All children – ``ObjectSnapshotProtocol/children``.
    /// - The object's parent – ``ObjectSnapshotProtocol/parent``.
    ///
    /// - SeeAlso: ``Frame/brokenReferences()``
    ///
    public static func brokenReferences(_ object: some ObjectProtocol,in frame: some Frame) -> Set<ObjectID> {
        // NOTE: Sync with brokenReferences() for all snapshots within the frame
        //
        var broken: Set<ObjectID> = []
        
        switch object.structure {
        case .unstructured: break // Nothing broken.
        case .node: break // Nothing broken.
        case let .edge(originID, targetID):
            if !frame.contains(originID) {
                broken.insert(originID)
            }
            if !frame.contains(targetID) {
                broken.insert(targetID)
            }
        case let .orderedSet(owner, ids):
            if !frame.contains(owner) {
                broken.insert(owner)
            }
            for id in ids {
                if !frame.contains(id) {
                    broken.insert(id)
                }
            }
        }
        
        if let parent = object.parent, !frame.contains(parent) {
            broken.insert(parent)
        }

        for id in object.children {
            if !frame.contains(id) {
                broken.insert(id)
            }
        }

        return broken
    }

    /// Validates complete structural integrity of a collection of snapshots
    ///
    /// The method validates structural integrity of objects:
    ///
    /// - Edge endpoints must exist within the frame and must be nodes.
    /// - Ordered set owner and references must exist in the frame.
    /// - Children-parent relationship must be mutual.
    /// - There must be no parent-child cycle.
    ///
    /// If the validation fails, detailed information can be provided by the ``brokenReferences()``
    /// method.
    ///
    /// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``Design/validate(_:metamodel:)``
    /// - Precondition: The frame must be in transient state – must not be
    ///   previously accepted or discarded.
    ///
    static func validate(snapshots: [ObjectSnapshot], in frame: some Frame)
    throws (StructuralIntegrityError) {
        // TODO: This is not quite correct, we should be validating within snapshots themselves as well, or not?
        // Check for parent-child cycles using topological traversal
        var parents: [(parent: ObjectID, child: ObjectID)] = []

        for object in snapshots {
            try validate(object, in: frame)
            if let parentID = object.parent {
                parents.append((parent: parentID, child: object.objectID))
            }
        }

        // Map: child -> parent
        let children = Set(parents.map { $0.child })
        var tops: [ObjectID] = parents.compactMap {
            if children.contains($0.parent) {
                nil
            }
            else {
                $0.parent
            }
        }

        while !tops.isEmpty {
            let topParent = tops.removeFirst()
            for (_, child) in parents.filter({ $0.parent == topParent }) {
                tops.append(child)
            }
            parents.removeAll { $0.parent == topParent }
        }

        if !parents.isEmpty {
            throw .parentChildCycle
        }
    }
    
    /// Get a list of object IDs that are referenced within the frame
    /// but do not exist in the frame.
    ///
    /// Frame with broken references can not be made stable and accepted
    /// by the design.
    ///
    /// The following references from the snapshot are being considered:
    ///
    /// - If the structure type is an edge (``Structure/edge(_:_:)``)
    ///   then the origin and target is considered.
    /// - All children – ``ObjectSnapshotProtocol/children``.
    /// - The object's parent – ``ObjectSnapshotProtocol/parent``.
    ///
    /// - Note: This is semi-internal function to validate correct workings
    ///   of the system. You should rarely use it. Typical scenario when you
    ///   want to use this function is when you are constructing a frame
    ///   in an unsafe way.
    ///
    /// - SeeAlso: ``Frame/brokenReferences(snapshot:)``
    ///
    public func brokenReferences(_ snapshots: [ObjectSnapshot], in frame: some Frame) -> Set<ObjectID> {
        // NOTE: Sync with brokenReferences(snapshot:)
        //
        var broken: Set<ObjectID> = []
        
        for snapshot in snapshots {
            broken.formUnion(Self.brokenReferences(snapshot, in: frame))
        }
        
        return broken
    }

}
