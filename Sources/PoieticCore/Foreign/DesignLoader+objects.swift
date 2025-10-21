//
//  DesignLoader+objects.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 18/10/2025.
//

extension DesignLoader { // Object snapshots
    internal func resolveObjectSnapshots(
        resolution: ValidationResolution,
        identities: IdentityResolution
    ) throws (DesignLoaderError) -> PartialSnapshotResolution
    {
        // Sanity check
        assert(identities.snapshotIDs.count == resolution.rawSnapshots.count)
        assert(identities.objectIDs.count == resolution.rawSnapshots.count)
        
        var snapshots: [ResolvedObjectSnapshot] = []
        
        for (i, rawSnapshot) in resolution.rawSnapshots.enumerated() {
            let snapshot: ResolvedObjectSnapshot
            do {
                snapshot = try resolveObjectSnapshot(
                    snapshotID: identities.snapshotIDs[i],
                    objectID: identities.objectIDs[i],
                    rawSnapshot: rawSnapshot,
                    identities: identities)
            }
            catch {
                throw .item(.objectSnapshots, i, error)
            }
            snapshots.append(snapshot)
        }

        return PartialSnapshotResolution(objectSnapshots: snapshots, identities: identities)
    }

    internal func resolveObjectSnapshot(
        snapshotID: ObjectSnapshotID,
        objectID: ObjectID,
        rawSnapshot: RawSnapshot,
        identities: IdentityResolution)
    throws (DesignLoaderError.ItemError) -> ResolvedObjectSnapshot
    {
        var refs: [ObjectID] = []
        
        for foreignRef in rawSnapshot.structure.references {
            guard let id: ObjectID = identities[foreignRef] else {
                throw .unknownID(foreignRef)
            }
            refs.append(id)
        }

        let parentID: ObjectID?
        
        if let foreignParent = rawSnapshot.parent {
            guard let id: ObjectID = identities[foreignParent] else {
                throw .unknownID(foreignParent)
            }
            parentID = id
        }
        else {
            parentID = nil
        }
                
        guard let typeName = rawSnapshot.typeName else {
            throw .missingObjectType
        }
        
        let structuralType: StructuralType?
        switch rawSnapshot.structure.type {
        case .none:
            structuralType = nil
        case "unstructured":
            structuralType = .unstructured
        case "node":
            structuralType = .node
        case "edge":
            structuralType = .edge
        default:
            throw .invalidStructuralType
        }
        
        var attributes: [String:Variant] = rawSnapshot.attributes

        // Version 0.0.1
        if compatibilityVersion == SemanticVersion(0, 0, 1)
                || (options.contains(.useIDAsNameAttribute))
        {
            if let id = rawSnapshot.objectID,
               case let .string(name) = id,
               attributes["name"] == nil
            {
                attributes["name"] = Variant(name)
            }
        }

        let snapshot = ResolvedObjectSnapshot(
            snapshotID: snapshotID,
            objectID: objectID,
            typeName: typeName,
            structuralType: structuralType,
            structureReferences: refs,
            parent: parentID,
            attributes: attributes
        )
        return snapshot
    }

    /// Create snapshots from raw snapshots.
    ///
    /// Reservation is created using ``reserveIdentities(snapshots:with:)``.
    ///
    internal func createSnapshots(resolution: SnapshotHierarchyResolution)
    throws (DesignLoaderError) -> [ObjectSnapshot]
    {
        var result: [ObjectSnapshot] = []
        
        for (i, resolvedSnapshot) in resolution.objectSnapshots.enumerated() {
            let snapshot: ObjectSnapshot

            do {
                snapshot = try createSnapshot(
                    resolvedSnapshot,
                    children: resolution.children[resolvedSnapshot.snapshotID]
                )
            }
            catch {
                throw .item(.objectSnapshots, i, error)
            }
            
            result.append(snapshot)
        }
        return result
    }

    /// Create a snapshot from its raw representation.
    ///
    /// Requirements:
    /// - Snapshot object type must exist in the metamodel.
    /// - Snapshot structural type must be valid and must match the object type.
    /// - All references must exist within the reservations.
    ///
    /// Reservation is created using ``reserveIdentities(snapshots:with:)``.
    ///
    internal func createSnapshot(
        _ resolvedSnapshot: ResolvedObjectSnapshot,
        children: [ObjectID]?
    ) throws (DesignLoaderError.ItemError) -> ObjectSnapshot
    {
        // IMPORTANT: Sync the logic (especially preconditions) as in TransientFrame.create(...)
        // TODO: Consider moving this to Design (as well as its TransientFrame counterpart)
        guard let type = metamodel.objectType(name: resolvedSnapshot.typeName) else {
            throw .unknownObjectType(resolvedSnapshot.typeName)
        }
        
        let structure: Structure
        let references = resolvedSnapshot.structureReferences
        switch resolvedSnapshot.structureType {
        case .none:
            switch type.structuralType {
            case .unstructured: structure = .unstructured
            case .node: structure = .node
            default: throw .structuralTypeMismatch(type.structuralType)
            }
        case .unstructured:
            guard type.structuralType == .unstructured else {
                throw .structuralTypeMismatch(type.structuralType)
            }
            structure = .unstructured
        case .node:
            guard type.structuralType == .node else {
                throw .structuralTypeMismatch(type.structuralType)
            }
            structure = .node
        case .edge:
            guard type.structuralType == .edge else {
                throw .structuralTypeMismatch(type.structuralType)
            }
            guard references.count == 2 else {
                throw .invalidStructuralType
            }
            structure = .edge(references[0], references[1])
        default:
            // Not supported type at this moment
            throw .invalidStructuralType
        }
        

        var attributes: [String:Variant] = resolvedSnapshot.attributes ?? [:]
        
        // Set default attributes according to the type
        // TODO: Should this be here?
        for attribute in type.attributes {
            guard attributes[attribute.name] == nil else { continue }
            attributes[attribute.name] = attribute.defaultValue
        }
        let children = children ?? []
        
        let snapshot = ObjectSnapshot(type: type,
                                      snapshotID: resolvedSnapshot.snapshotID,
                                      objectID: resolvedSnapshot.objectID,
                                      structure: structure,
                                      parent: resolvedSnapshot.parent,
                                      children: children,
                                      attributes: attributes)
        return snapshot
    }

} // extension Object snapshots
