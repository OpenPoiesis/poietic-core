//
//  LoadingContext+NEW.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 15/10/2025.
//

extension DesignLoader {
    struct ValidatedLoadingContext {
        let identityManager: IdentityManager
        /// Validated raw snapshots, no duplicate IDs.
        let rawSnapshots: [RawSnapshot]
        /// Validated raw frames, no duplicate IDs.
        let rawFrames: [RawFrame]
//        let unavailableIDs: Set<EntityID.RawValue>
    }
  
    // Used in: resolve identities
    struct ReservationContext {
        let unavailableIDs: Set<EntityID.RawValue>
        var reserved: [EntityID.RawValue] = []
        var rawIDMap: [ForeignEntityID:EntityID.RawValue] = [:]
    }
    

    struct IdentityResolution {
        let reserved: [EntityID.RawValue]
        let rawIDMap: [ForeignEntityID:EntityID.RawValue]
        let frameIDs: [FrameID]
        let snapshotIDs: [ObjectSnapshotID]
        let objectIDs: [ObjectID]
        let snapshotIndex: [ObjectSnapshotID:Int]
        
//        subscript(foreignID: ForeignEntityID) -> EntityID.RawValue? {
//            rawIDMap[foreignID]
//        }
        subscript<T>(foreignID: ForeignEntityID) -> EntityID<T>? {
            guard let value = rawIDMap[foreignID] else { return nil }
            return EntityID<T>(rawValue: value)
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
            self.children = children
            self.attributes = attributes
        }
    }
    struct ObjectResolution {
        let resolvedSnapshots: [LoadingContext.ResolvedObjectSnapshot]
    }
    struct ResolvedFrames {
        
    }
    struct HierarchyResolution {
        
    }
}
