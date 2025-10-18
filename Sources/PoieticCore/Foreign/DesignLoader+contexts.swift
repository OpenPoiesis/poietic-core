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
    struct ValidatedLoadingContext {
        // TODO: Rename to ValidatedRawDesign
        // TODO: Include translated object types for named references and lists
        let identityManager: IdentityManager
        /// Validated raw snapshots, no duplicate IDs.
        let rawSnapshots: [RawSnapshot]
        /// Validated raw frames, no duplicate IDs.
        let rawFrames: [RawFrame]
//        let unavailableIDs: Set<EntityID.RawValue>
    }
  
    // Used in: resolve identities
    /// Stage 2 context: Reser
    ///
    /// Input for identity resolution.
    struct ReservationContext {
        let unavailableIDs: Set<EntityID.RawValue>
        /// All reserved IDs regardless of their type. This collection is used to accept or release
        /// the reservations.
        ///
        var reserved: [EntityID.RawValue] = []
        
        /// Mapping between raw model references and their actual identities.
        ///
        var rawIDMap: [ForeignEntityID:EntityID.RawValue] = [:]
    }
    
    /// Stage 3 context.
    ///
    struct IdentityResolution {
        /// All reserved IDs regardless of their type. This collection is used to accept or release
        /// the reservations.
        ///
        let reserved: [EntityID.RawValue]
        /// Mapping between raw model references and their actual identities.
        ///
        let rawIDMap: [ForeignEntityID:EntityID.RawValue]
        /// Reserved identities for raw frames.
        ///
        /// The items correspond to ``ValidatedLoadingContext/rawFrames``.
        ///
        let frameIDs: [FrameID]

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
        /// This is used for frame content resolution and for error reporting.
        ///
        let snapshotIndex: [ObjectSnapshotID:Int]
        
        subscript<T>(foreignID: ForeignEntityID) -> EntityID<T>? {
            guard let value = rawIDMap[foreignID] else { return nil }
            return EntityID<T>(rawValue: value)
        }

        subscript(foreignID: ForeignEntityID) -> EntityID.RawValue? {
            return rawIDMap[foreignID]
        }

    }

    // TODO: Pick a better name or split to snapshot/hierarchy
    struct ResolvedObjectSnapshot {
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
        
        let structureType: StructuralType?
        let structureReferences: [ObjectID]
        
        let parent: ObjectID?
        
        let attributes: [String:Variant]?
        
        internal init(snapshotID: ObjectSnapshotID,
                      objectID: ObjectID,
                      typeName: String,
                      structuralType: StructuralType?,
                      structureReferences: [ObjectID] = [],
                      parent: ObjectID? = nil,
                      children: [ObjectID]? = nil,
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
    struct ObjectResolution {
        let resolvedSnapshots: [ResolvedObjectSnapshot]
    }
    struct ResolvedFrame {
        let frameID: FrameID
        /// Index of the snapshot in the ``IdentityResolution`` or to list of resolved snapshots.
        // TODO: Reconsider necessity of the index, maybe just have snapshot ID -> (objectID) map
        let snapshotIndices: [Int]
    }
    
    /// Mutable context using during hierarchy resolution of multiple frames.
    struct HierarchyResolutionContext {
        /// Mapping between snapshot index and children list.
        var children: [Int:[ObjectID]]
    }
    
    struct ResolvedNamedReferences {
        let systemLists: [String:NamedReferenceList]
        let systemReferences: [String:NamedReference]
        let userLists: [String:NamedReferenceList]
        let userReferences: [String:NamedReference]
    }
}
