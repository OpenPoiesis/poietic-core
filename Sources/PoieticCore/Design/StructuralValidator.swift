//
//  StructuralValidator.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 06/11/2025.
//

/// Namespace for snapshot and plane validation methods.
///

public struct StructuralValidator {
    /// Validates that snapshot's structural references within a context of a plane.
    ///
    /// Intended use is to check whether the snapshot can be added to a plane.
    ///
    /// What is validated:
    ///
    /// - Parent exist in the plane.
    /// - Children exist in the plane.
    /// - If it is an edge: whether origin and target exist in the plane and are of type
    ///   ``StructuralType/node``.
    /// - If it is an ordered set: whether the owner and all IDs exist in the plane.
    ///
    /// The validator does not check anything related to metamodel. This is a low-level structural
    /// validation, without any model semantic checks.
    ///
    /// - SeeAlso: Use ``ConstraintChecker`` to validate design semantics through ``Metamodel``.
    ///
    public static func validate(_ object: some ObjectProtocol, in plane: some Plane)
    throws (StructuralIntegrityError) {
        switch object.structure {
        case .unstructured: break // Nothing to validate.
        case .node: break // Nothing to validate.
        case let .edge(originID, targetID):
            guard let origin = plane[originID],
                  let target = plane[targetID]
            else {
                throw .brokenStructureReference
            }
            guard origin.structure == .node && target.structure == .node else {
                throw .edgeEndpointNotANode
            }
        case let .orderedSet(owner, ids):
            guard plane.contains(owner) && ids.allSatisfy({plane.contains($0)}) else {
                throw .brokenStructureReference
            }
        }

        for childID in object.children {
            guard let child = plane[childID] else {
                throw .brokenChild
            }
            guard child.parent == object.objectID else {
                throw .parentChildMismatch
            }
        }

        if let parentID = object.parent {
            guard let parent = plane[parentID] else {
                throw .brokenParent
            }
            
            guard parent.children.contains(object.objectID) else {
                throw .parentChildMismatch
            }
        }
    }

    /// Return a list of objects that the provided object refers to and
    /// that do not exist within the plane.
    ///
    /// Plane with broken references can not be made stable and accepted
    /// by the design.
    ///
    /// The following references from the snapshot are being considered:
    ///
    /// - If the structure type is an edge (``Structure/edge(_:_:)``)
    ///   then the origin and target is considered.
    /// - All children – ``ObjectProtocol/children``.
    /// - The object's parent – ``ObjectProtocol/parent``.
    ///
    public static func brokenReferences(_ object: some ObjectProtocol, in plane: some Plane) -> Set<ObjectID> {
        // NOTE: Sync with brokenReferences() for all snapshots within the plane
        //
        var broken: Set<ObjectID> = []
        
        switch object.structure {
        case .unstructured: break // Nothing broken.
        case .node: break // Nothing broken.
        case let .edge(originID, targetID):
            if !plane.contains(originID) {
                broken.insert(originID)
            }
            if !plane.contains(targetID) {
                broken.insert(targetID)
            }
        case let .orderedSet(owner, ids):
            if !plane.contains(owner) {
                broken.insert(owner)
            }
            for id in ids {
                if !plane.contains(id) {
                    broken.insert(id)
                }
            }
        }
        
        if let parent = object.parent, !plane.contains(parent) {
            broken.insert(parent)
        }

        for id in object.children {
            if !plane.contains(id) {
                broken.insert(id)
            }
        }

        return broken
    }

    /// Validates complete structural integrity of a collection of snapshots
    ///
    /// The method validates structural integrity of objects:
    ///
    /// - Edge endpoints must exist within the plane and must be nodes.
    /// - Ordered set owner and references must exist in the plane.
    /// - Children-parent relationship must be mutual.
    /// - There must be no parent-child cycle.
    ///
    /// If the validation fails, detailed information can be provided by the ``brokenReferences()``
    /// method.
    ///
    /// The validator does not check anything related to metamodel. This is a low-level structural
    /// validation, without any model semantic checks.
    ///
    /// - Precondition: The plane must be in transient state – must not be
    ///   previously accepted or discarded.
    ///
    /// - SeeAlso: ``Design/accept(_:appendHistory:)``, ``Design/validate(_:metamodel:)``
    /// - SeeAlso: Use ``ConstraintChecker`` to validate design semantics through ``Metamodel``.
    static func validate(snapshots: [ObjectSnapshot], in plane: some Plane)
    throws (StructuralIntegrityError) {
        // TODO: This is not quite correct, we should be validating within snapshots themselves as well, or not?
        // Check for parent-child cycles using topological traversal
        var parents: [(parent: ObjectID, child: ObjectID)] = []

        for object in snapshots {
            try validate(object, in: plane)
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
    
    /// Get a list of object IDs that are referenced within the plane
    /// but do not exist in the plane.
    ///
    /// Plane with broken references can not be made stable and accepted
    /// by the design.
    ///
    /// The following references from the snapshot are being considered:
    ///
    /// - If the structure type is an edge (``Structure/edge(_:_:)``)
    ///   then the origin and target is considered.
    /// - All children – ``ObjectProtocol/children``.
    /// - The object's parent – ``ObjectProtocol/parent``.
    ///
    /// - Note: This is semi-internal function to validate correct workings
    ///   of the system. You should rarely use it. Typical scenario when you
    ///   want to use this function is when you are constructing a plane
    ///   in an unsafe way.
    ///
    /// - SeeAlso: ``StructuralValidator/validate(_:in:)``
    ///
    public func brokenReferences(_ snapshots: [ObjectSnapshot], in plane: some Plane) -> Set<ObjectID> {
        // NOTE: Sync with brokenReferences(snapshot:)
        //
        var broken: Set<ObjectID> = []
        
        for snapshot in snapshots {
            broken.formUnion(Self.brokenReferences(snapshot, in: plane))
        }
        
        return broken
    }

}
