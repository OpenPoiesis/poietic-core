//
//  LoadingContext+NEW.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 15/10/2025.
//

extension DesignLoader {
    /// Stage 1 context: Validated raw design.
    ///
    /// Used as input for validation.
    ///
    /// Next stage: ``ReservationContext``.
    ///
    struct ValidationResolution {
        // TODO: Include translated object types for named references and lists
        let identityManager: IdentityManager
        /// Validated raw snapshots, no duplicate IDs.
        let rawSnapshots: [RawSnapshot]
        /// Validated raw planes, no duplicate IDs.
        let rawPlanes: [RawPlane]
//        let unavailableIDs: Set<EntityID.RawValue>

        internal init(identityManager: IdentityManager,
                      rawSnapshots: [RawSnapshot] = [],
                      rawPlanes: [RawPlane] = []) {
            self.identityManager = identityManager
            self.rawSnapshots = rawSnapshots
            self.rawPlanes = rawPlanes
        }
    }
  
    /// Context used during identity reservation.
    ///
    /// Result will be finalised as ``IdentityResolution``.
    ///
    struct ReservationContext {
        let unavailableIDs: Set<DesignEntityID>
        /// All reserved IDs regardless of their type. This collection is used to accept or release
        /// the reservations.
        ///
        var reserved: [DesignEntityID] = []
        
        /// Mapping between raw model references and their actual identities.
        ///
        var rawIDMap: [RawEntityID:DesignEntityID] = [:]
    }
    
    /// Gathered and reserved identities that will be used through the loading process.
    ///
    class IdentityResolution {
        /// All reserved IDs regardless of their type. This collection is used to accept or release
        /// the reservations.
        ///
        let reserved: [DesignEntityID]
        /// Mapping between raw model references and their actual identities.
        ///
        let rawIDMap: [RawEntityID:DesignEntityID]
        /// Reserved identities for raw planes.
        ///
        /// The items correspond to ``ValidatedLoadingContext/rawPlanes``.
        ///
        let planeIDs: [PlaneID]

        /// Reserved identities for all snapshots to be loaded.
        ///
        /// The items correspond to ``ValidatedLoadingContext/rawSnapshots``.
        ///
        let snapshotIDs: [ObjectSnapshotID]
        
        /// Reserved object identities of object snapshots.
        ///
        /// The items correspond to ``snapshotIDs``
        ///
        let objectIDs: [ObjectID]
        
        /// Mapping between snapshot ID and its index in the list of snapshots.
        ///
        /// This is used for plane content resolution and for error reporting.
        ///
        let snapshotIndex: [ObjectSnapshotID:Int]

        internal init(reserved: [DesignEntityID],
                      rawIDMap: [RawEntityID : DesignEntityID],
                      planeIDs: [PlaneID],
                      snapshotIDs: [ObjectSnapshotID],
                      objectIDs: [ObjectID],
                      snapshotIndex: [ObjectSnapshotID : Int])
        {
            self.reserved = reserved
            self.rawIDMap = rawIDMap
            self.planeIDs = planeIDs
            self.snapshotIDs = snapshotIDs
            self.objectIDs = objectIDs
            self.snapshotIndex = snapshotIndex
        }

        subscript(foreignID: RawEntityID) -> DesignEntityID? {
            return rawIDMap[foreignID]
        }
    }

    /// Data of an object snapshot where the references, topology type, topology references,
    /// parent are resolved. Attributes are prepared.
    ///
    /// Only thing that is missing is list of children, that require context of a plane to be
    /// resolved, because use object IDs.
    ///
    /// - Note: If the loader has option ``DesignLoader/Options/useIDAsNameAttribute``, and if the
    ///   corresponding raw object snapshot snapshot ID is defined as string, then the string ID
    ///   will be used as an attribute `name`, if it is not provided explicitly. This is a backward
    ///   compatibility feature that will be removed in the future.
    ///
    class ResolvedObjectSnapshot {
        /// Final object snapshot ID.
        ///
        /// If the phase is `Phase/empty` then the property contains an ID that is being requested.
        /// Actual reserved ID will depend on the identity strategy.
        ///
        let snapshotID: ObjectSnapshotID
        /// Requested or reserved object ID.
        ///
        /// If the phase is `Phase/empty` then the property contains an ID that is being requested.
        /// Actual reserved ID will depend on the identity strategy.
        ///
        let objectID: ObjectID
        
        let typeName: String
        
        let structureType: TopologyType?
        let structureReferences: [ObjectID]
        
        let parent: ObjectID?
        
        let attributes: [String:Variant]?
        
        internal init(snapshotID: ObjectSnapshotID,
                      objectID: ObjectID,
                      typeName: String,
                      structuralType: TopologyType?,
                      structureReferences: [ObjectID] = [],
                      parent: ObjectID? = nil,
                      attributes: [String:Variant]? = nil) {
            self.snapshotID = snapshotID
            self.objectID = objectID
            self.typeName = typeName
            self.structureType = structuralType
            self.structureReferences = structureReferences
            self.parent = parent
            self.attributes = attributes
        }
    }
    
    /// Plane with assigned object snapshot IDs, so that the plane can be constructed.
    ///
    struct ResolvedPlane {
        let planeID: PlaneID
        let snapshots: [ObjectSnapshotID]
    }
    
    struct PlaneResolution {
        let planes: [ResolvedPlane]
    }
    
    /// All snapshots in the loading batch (from raw design or list of raw snapshots) that have
    /// all references resolved except children.
    ///
    /// - SeeAlso: ``SnapshotHierarchyResolution`` as a next step.
    ///
    struct PartialSnapshotResolution {
        /// Mapping between snapshot index and children list.
        let objectSnapshots: [ResolvedObjectSnapshot]
        let identities: IdentityResolution
        
        subscript(id: ObjectSnapshotID) -> ResolvedObjectSnapshot? {
            guard let index = identities.snapshotIndex[id] else { return nil }
            return objectSnapshots[index]
        }
    }

    /// Mutable context using during hierarchy resolution of multiple planes.
    struct SnapshotHierarchyResolution {
        /// Mapping between snapshot index and children list.
        let objectSnapshots: [ResolvedObjectSnapshot]
        let children: [ObjectSnapshotID:[ObjectID]]
        let identities: IdentityResolution
        
        subscript(id: ObjectSnapshotID) -> ResolvedObjectSnapshot? {
            guard let index = identities.snapshotIndex[id] else { return nil }
            return objectSnapshots[index]
        }
    }

    struct ResolvedNamedReferences {
        let systemLists: [String:NamedReferenceList]
        let systemReferences: [String:NamedReference]
        let userLists: [String:NamedReferenceList]
        let userReferences: [String:NamedReference]
    }
}
