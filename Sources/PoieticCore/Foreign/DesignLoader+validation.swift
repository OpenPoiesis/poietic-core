//
//  DesignLoader+validation.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 14/10/2025.
//

extension DesignLoader {
    /// Initial validation of the raw design.
    ///
    /// The method validates:
    ///
    /// - Whether the object snapshot IDs and frame IDs, if provided, are unique
    ///
    /// - Returns: Validated context that is meant to be used as an input for identity resolution.
    /// - Note: This is just preliminary validation required for identity resolution, it does not
    ///         validate structural integrity. It is not possible to validate structural integrity
    ///         at this stage, because we do not have all necessary information about object
    ///         references.
    ///
    internal func validate(rawDesign: RawDesign, identityManager: IdentityManager)
        throws (DesignLoaderError) -> ValidationResolution
    {
        // 1. Validate duplicate IDs.
        var seen: Set<ForeignEntityID> = Set()
        
        for (index, snapshot) in rawDesign.snapshots.enumerated() {
            guard let id = snapshot.snapshotID else { continue }
            if seen.contains(id) {
                throw .item(.objectSnapshots, index, .duplicateForeignID(id))
            }
            seen.insert(id)
        }

        for (index, frame) in rawDesign.frames.enumerated() {
            guard let id = frame.id else { continue }
            if seen.contains(id) {
                throw .item(.frames, index, .duplicateForeignID(id))
            }
            seen.insert(id)
        }
        
        // 2. Validate Named References and Lists
        var seenNames: Set<String> = Set()
        
        for (index, ref) in rawDesign.systemReferences.enumerated() {
            guard self.entityType(ref.type) != nil else {
                throw .item(.systemReferences, index, .unknownEntityType(ref.type))
            }
            guard !seenNames.contains(ref.name) else {
                throw .item(.systemReferences, index, .duplicateName(ref.name))
            }
            seenNames.insert(ref.name)
        }
        
        seenNames.removeAll()
        
        for (index, ref) in rawDesign.userReferences.enumerated() {
            guard self.entityType(ref.type) != nil  else {
                throw .item(.userReferences, index, .unknownEntityType(ref.type))
            }
            guard !seenNames.contains(ref.name) else {
                throw .item(.userReferences, index, .duplicateName(ref.name))
            }
            seenNames.insert(ref.name)
        }

        seenNames.removeAll()

        for (listIndex, list) in rawDesign.systemLists.enumerated() {
            guard self.entityType(list.itemType) != nil  else {
                throw .item(.systemLists, listIndex, .unknownEntityType(list.itemType))
            }
            guard !seenNames.contains(list.name) else {
                throw .item(.systemLists, listIndex, .duplicateName(list.name))
            }
            seenNames.insert(list.name)
        }

        seenNames.removeAll()

        for (listIndex, list) in rawDesign.userLists.enumerated() {
            guard self.entityType(list.itemType) != nil  else {
                throw .item(.userLists, listIndex, .unknownEntityType(list.itemType))
            }
            guard !seenNames.contains(list.name) else {
                throw .item(.userLists, listIndex, .duplicateName(list.name))
            }
            seenNames.insert(list.name)
        }


        return ValidationResolution(identityManager: identityManager,
                                       rawSnapshots: rawDesign.snapshots,
                                       rawFrames: rawDesign.frames)
        
    }

}
