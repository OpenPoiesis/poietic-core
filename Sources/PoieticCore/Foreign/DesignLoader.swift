//
//  RawDesignLoader.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//

// FIXME: Introduce DesignLoaderError.internalError and use instead of precondition failures (be nicer to the user)

/*

 Loader versions:
 
 0.0.1:
    - allow names as IDs
 0.1.0:
    - do not allow names as IDs
 
 */


/*
 
             validate
                 ↓
         resolveIdentities
                 ↓
     ┌────────────┴────────────┐
     ↓                         ↓
resolveFrames          resolveObjectSnapshots
     ↓                         ↓
     └────────────┬────────────┘
                  ↓
    resolveHierarchy (2 versions)
                  ↓
            createSnapshots
                  ↓
     ┌────────────┴────────────┐
     ↓                         ↓
insertFrames          frame.unsafeInsert
     ↓
resolveNamedReferences
     ↓
finaliseDesign

 */


/// Object that loads raw representation of design or design entities into a design.
///
/// The design loader is the primary way of constructing whole design or its components from
/// foreign representations that were converted into raw design entities
/// (``RawSnapshot``, ``RawFrame``, ``RawDesign``, ...).
///
/// The typical application use-cases for the design loader are:
/// - Create a design from an external representation such as a file. See ``JSONDesignReader`` and
///   ``load(_:)``.
/// - Import from another design. See ``load(_:into:)-(RawDesign,_)``.
/// - Paste from a pasteboard during Copy & Paste operation. See ``load(_:into:)-([RawSnapshot],_)``,
///   and ``JSONDesignWriter``.
///
/// The main responsibilities of the deign loader are:
/// - Reservation of object identities.
/// -
public class DesignLoader {
    public let metamodel: Metamodel
    let compatibilityVersion: SemanticVersion?
    static let MakeshiftJSONLoaderVersion = SemanticVersion(0, 0, 1)
    public let options: Options
    
    public enum IdentityStrategy {
        /// Loading operation requires that all provided identities are preserved.
        case requireProvided
        
        // Identities are preserved, if they are available. Otherwise new identities will be
        // created.
        case preserveOrCreate
        
        /// All identities will be created as new.
        case createNew
    }
    
    /// Options of the loading process.
    ///
    public struct Options: OptionSet, Sendable {
        public typealias RawValue = Int
        
        public var rawValue: Int
        public init() {
            self.rawValue = 0
        }
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// When snapshot ID is a string, use it as a name attribute, if not present.
        public static let useIDAsNameAttribute = Options(rawValue: 1 << 0)
    }
    
    public init(metamodel: Metamodel, options: Options = Options(), compatibilityVersion version: SemanticVersion? = nil) {
        self.metamodel = metamodel
        self.compatibilityVersion = version
        self.options = options
    }

    // MARK: - Loading
    
    /// Loads a raw design and creates new design.
    ///
    /// The loading procedure is as follows:
    /// 1. Reserve identities for snapshots and frames.
    /// 2. Create snapshots and frames.
    /// 3. Validate frames.
    /// 4. Create a new design.
    ///
    public func load(_ rawDesign: RawDesign) throws (DesignLoaderError) -> Design {
        // The loader uses something similar to a pipeline pattern.
        // Stages are separate steps that use only relevant processing context and produce value for the next step.
        let design: Design = Design(metamodel: metamodel)
        
        let validationResolution = try validate(
            rawDesign: rawDesign,
            identityManager: design.identityManager
        )
        let identityResolution = try resolveIdentities(
            resolution: validationResolution,
            identityStrategy: .requireProvided
        )
        
        let partialSnapshotResolution = try resolveObjectSnapshots(
            resolution: validationResolution,
            identities: identityResolution,
        )
        
        let frameResolution = try resolveFrames(
            resolution: validationResolution,
            identities: identityResolution,
        )
        
        // We have:
        // - referenced snapshots exist
        // - there are no duplicate object IDs within frame
        let hierarchicalSnapshots  = try resolveHierarchy(
            frameResolution: frameResolution,
            snapshotResolution: partialSnapshotResolution
        )
        // Parent reference (if present) points to objectID that exists in same frame
        // All children references point to objectIDs that exist in same frame
        // Bidirectional consistency: if A has child B, then B has parent A
        
        
        // 3. Create Snapshots
        // ----------------------------------------------------------------------
        let snapshots = try createSnapshots(resolution: hierarchicalSnapshots)

        var snapshotMap: [ObjectSnapshotID:ObjectSnapshot] = [:]
        for snapshot in snapshots {
            snapshotMap[snapshot.snapshotID] = snapshot
        }
        
        // 4. Load (commit)
        
        try insertFrames(
            resolvedFrames: frameResolution.frames,
            snapshots: snapshots,
            snapshotMap: snapshotMap,
            into: design
        )
        
        // FIXME: [IMPORTANT] We need guarantee that the raw design corresponds to the identity reservations
        let namedReferences = try resolveNamedReferences(
            rawDesign: rawDesign,
            identities: identityResolution
        )
        
        try finaliseDesign(design: design, namedReferences: namedReferences)
        
        design.identityManager.use(reserved: identityResolution.reserved)
        
        return design
    }
    
    /// Loads current frame of the design into a transient frame.
    ///
    /// This is used for foreign design imports.
    ///
    /// Requirements:
    ///
    /// - With current frame: the first frame in the frame list with current frame ID is loaded.
    /// - Without current frame: All snapshots will be used, but must not have any frames defined.
    ///
    /// - SeeAlso: ``load(_:into:)-1o6qf``
    ///
    public func load(_ rawDesign: RawDesign, into frame: TransientFrame) throws (DesignLoaderError) {

        // 1. If there is current frame:
        //    1.1. Find all snapshots with given ID
        //    1.2. throw error if not found
        // 2. Make sure all snapshot IDs are unique
        
        var snapshots: [RawSnapshot] = []
        
        if let currentFrameID = rawDesign.currentFrameID {
            guard let frameIndex = rawDesign.frames.firstIndex(where: { $0.id == currentFrameID }) else {
                throw .design(.unknownFrameID(currentFrameID))
            }
            
            let currentFrame = rawDesign.frames[frameIndex]
            
            for snapshotID in currentFrame.snapshots {
                guard let snapshot = rawDesign.first(snapshotWithID: snapshotID) else {
                    throw .item(.frames, frameIndex, .unknownID(snapshotID))
                }
                snapshots.append(snapshot)
            }
        }
        else {
            guard rawDesign.frames.isEmpty else {
                throw .design(.missingCurrentFrame)
            }
            snapshots = rawDesign.snapshots
        }
        try load(snapshots, into: frame)
    }
    
    /// Load raw snapshots into a transient frame.
    ///
    /// - Parameters:
    ///     - rawSnapshots: List of raw snapshots to be loaded into the frame.
    ///     - identityStrategy: Strategy used to generate or preserve provided raw IDs.
    ///
    /// - Returns: List of object IDs of inserted object.
    ///
    /// This method is intended to be used when importing external frames or for pasting in the
    /// Copy & Paste mechanism.
    ///
    @discardableResult
    internal func load(_ rawSnapshots: [RawSnapshot],
                       into frame: TransientFrame,
                       identityStrategy: IdentityStrategy = .requireProvided)
    throws (DesignLoaderError) -> [ObjectID] {
        let identityResolution: DesignLoader.IdentityResolution
        
        // FIXME: [IMPORTANT] Release reservations!!!
        let rawDesign = RawDesign(snapshots: rawSnapshots)

        let validationResolution = try validate(
            rawDesign: rawDesign,
            identityManager: frame.design.identityManager
        )
        
        identityResolution = try resolveIdentities(
            resolution: validationResolution,
            identityStrategy: .requireProvided
        )
        
        let snapshotResolution = try resolveObjectSnapshots(
            resolution: validationResolution,
            identities: identityResolution
        )

        let completeSnapshots = try resolveHierarchy(
            resolution: snapshotResolution
        )

        let snapshots = try createSnapshots(
            resolution: completeSnapshots
        )
        
        frame.unsafeInsert(snapshots, reservations: completeSnapshots.identities.reserved)
        
        do {
            // TODO: [WIP] Is this needed?
            try frame.validateStructure()
        }
        catch {
            throw .item(.frames, 0, .brokenStructuralIntegrity(error))
        }
        return snapshots.map { $0.objectID }
    }
    
    // MARK: - Frames
    
    internal func resolveFrames(resolution: ValidationResolution,
                                identities: IdentityResolution)
    throws (DesignLoaderError) -> FrameResolution
    {
        precondition(resolution.rawFrames.count == identities.frameIDs.count)
        
        var resolvedFrames: [ResolvedFrame] = []
        
        var frameIndex = 0
        for (frameID, rawFrame) in zip(identities.frameIDs, resolution.rawFrames) {
            let ids: [ObjectSnapshotID]
            
            do {
                ids = try resolveFrame(rawFrame, identities: identities)
            }
            catch {
                throw .item(.frames, frameIndex, error)
            }
            let resolved = ResolvedFrame(frameID: frameID, snapshots: ids)
            resolvedFrames.append(resolved)
            frameIndex += 1
        }
        
        return FrameResolution(frames: resolvedFrames)
    }
    
    /// - Returns: List of indices of object snapshots in the list of all snapshots.
    ///
    internal func resolveFrame(_ frame: RawFrame, identities: IdentityResolution)
    throws (DesignLoaderError.ItemError) -> [ObjectSnapshotID]
    {
        var ids: [ObjectSnapshotID] = []
        for foreignSnapshotID in frame.snapshots {
            guard let id: ObjectSnapshotID = identities[foreignSnapshotID] else {
                throw .unknownSnapshotID(foreignSnapshotID)
            }
            ids.append(id)
        }
        return ids
    }
    
    // MARK: - Hierarchy
    /// Resolve parent-child hierarchy of object snapshots.
    ///
    /// The method requires the frames to be resolved.
    internal func resolveHierarchy(frameResolution: FrameResolution,
                                   snapshotResolution: PartialSnapshotResolution)
    throws (DesignLoaderError) -> SnapshotHierarchyResolution
    {
        var finalChildrenMap: [ObjectSnapshotID:[ObjectID]] = [:] // All children resolved
        
        for (frameIndex, frame) in frameResolution.frames.enumerated() {
            let childrenMap: [ObjectSnapshotID:[ObjectID]] // Children resolved within frame
            var snapshots: [ResolvedObjectSnapshot] = []
            for id in frame.snapshots {
                guard let snapshot = snapshotResolution[id] else {
                    preconditionFailure("Bad snapshot resolution")
                }
                snapshots.append(snapshot)
            }
            
            do {
                childrenMap = try resolveChildren(snapshots: snapshots,
                                                  snapshotResolution: snapshotResolution)
            }
            catch {
                throw .item(.objectSnapshots, error.index, error.error)
            }
            
            // Integrity check: validate created children lists whether they match
            // existing children list.
            for (index, resolved) in childrenMap {
                if let existing = finalChildrenMap[index], resolved != existing {
                    throw .item(.frames, frameIndex, .childrenMismatch)
                }
                else {
                    finalChildrenMap[index] = resolved
                }
            }
        }
        return SnapshotHierarchyResolution(
            objectSnapshots: snapshotResolution.objectSnapshots,
            children: finalChildrenMap,
            identities: snapshotResolution.identities
        )
    }
    
    // Resolve all children in the resolution without frames.
    internal func resolveHierarchy(resolution: PartialSnapshotResolution)
    throws (DesignLoaderError) -> SnapshotHierarchyResolution
    {
        let childrenMap: [ObjectSnapshotID:[ObjectID]] // Children resolved within frame
        do {
            childrenMap = try resolveChildren(snapshots: resolution.objectSnapshots,
                                              snapshotResolution: resolution)
        }
        catch {
            throw .item(.objectSnapshots, error.index, error.error)
        }
        return SnapshotHierarchyResolution(
            objectSnapshots: resolution.objectSnapshots,
            children: childrenMap,
            identities: resolution.identities
        )
    }
    
    /// Resolve children references within a group of objects.
    ///
    /// The group of objects is typically a frame.
    ///
    /// This method requires that the ``LoadingContext/parents`` has been populated.
    ///
    /// - Parameters:
    ///     - snapshotIndices: Indices of snapshots within a frame (or some other similar
    ///         collection) to the list of all snapshots. See: ``RawDesign/snapshots``.
    ///     - objectSnapshots: All object snapshots.
    ///
    /// - Throws an error with offending snapshot index, where the index is referring to
    ///   an index in ``StagingSnapshotResolution/identities`` – that is, global snapshot index.
    ///
    internal func resolveChildren(snapshots: [ResolvedObjectSnapshot],
                                  snapshotResolution: PartialSnapshotResolution)
    throws (DesignLoaderError.IndexedItemError) -> [ObjectSnapshotID:[ObjectID]]
    {
        var objectToSnapshot: [ObjectID:ObjectSnapshotID] = [:]
        var childrenMap: [ObjectSnapshotID:[ObjectID]] = [:]
        
        for snapshot in snapshots {
            assert(objectToSnapshot[snapshot.objectID] == nil)
            objectToSnapshot[snapshot.objectID] = snapshot.snapshotID
        }
        
        for snapshot in snapshots {
            guard let parentID = snapshot.parent else { continue }
            guard let parentSnapshotID = objectToSnapshot[parentID] else {
                guard let index = snapshotResolution.identities.snapshotIndex[snapshot.snapshotID] else {
                    preconditionFailure("Broken snapshot resolution")
                }
                // Use "global" snapshot index for meaningful error propagation.
                throw DesignLoaderError.IndexedItemError(index, .unknownParent)
            }
            
            let childObjectID = snapshot.objectID
            childrenMap[parentSnapshotID, default: []].append(childObjectID)
        }
        
        return childrenMap
    }
    
    internal func insertFrames(resolvedFrames: [ResolvedFrame],
                               snapshots: [ObjectSnapshot],
                               snapshotMap: [ObjectSnapshotID:ObjectSnapshot],
                               into design: Design)
    throws (DesignLoaderError)
    {
        var frames: [DesignFrame] = []
        
        for (i, resolvedFrame) in resolvedFrames.enumerated() {
            // TODO: Can we get rid of force unwraps here? (both)
            precondition(!design.containsFrame(resolvedFrame.frameID))
            let frameSnapshots = resolvedFrame.snapshots.compactMap { snapshotMap[$0] }
            
            let frame = DesignFrame(design: design,
                                    id: resolvedFrame.frameID,
                                    snapshots: frameSnapshots)
            
            do {
                try frame.validateStructure()
            }
            catch {
                throw .item(.frames, i, .brokenStructuralIntegrity(error))
            }
            frames.append(frame)
        }
        for frame in frames {
            design.unsafeInsert(frame)
        }
    }
    
    
    // MARK: - Finalise
    
    struct NamedReference {
        let type: IdentityType
        let id: EntityID.RawValue
    }
    struct NamedReferenceList {
        let type: IdentityType
        let ids: [EntityID.RawValue]
        
        func typedIDs<T>() -> [EntityID<T>] {
            return ids.map { EntityID(rawValue: $0) }
        }
    }
    func resolveNamedReferences(
        // FIXME: [IMPORTANT] We need guarantee that the raw design corresponds to the identity reservations
        rawDesign: RawDesign,
        identities: IdentityResolution
    )
    throws (DesignLoaderError) -> ResolvedNamedReferences
    {
        let systemReferences: [String:NamedReference]
        let userReferences: [String:NamedReference]
        let systemLists: [String:NamedReferenceList]
        let userLists: [String:NamedReferenceList]
        
        do {
            try systemReferences = makeNamedReferences(rawDesign.systemReferences,
                                                       identities: identities)
        }
        catch {
            throw .item(.systemReferences, error.index, error.error)
        }
        
        
        do {
            try userReferences = makeNamedReferences(rawDesign.userReferences,
                                                     identities: identities)
        }
        catch {
            throw .item(.userReferences, error.index, error.error)
        }
        
        do {
            try systemLists = makeNamedReferenceList(rawDesign.systemLists,
                                                     identities: identities)
        }
        catch {
            throw .item(.systemLists, error.index, error.error)
        }
        do {
            try userLists = makeNamedReferenceList(rawDesign.userLists,
                                                   identities: identities)
        }
        catch {
            throw .item(.userLists, error.index, error.error)
        }
        
        return ResolvedNamedReferences(
            systemLists: systemLists,
            systemReferences: systemReferences,
            userLists: userLists,
            userReferences: userReferences
        )
    }
    
    internal func makeNamedReferences(_ refs: [RawNamedReference],
                                      identities: IdentityResolution)
    throws (DesignLoaderError.IndexedItemError) -> [String:NamedReference]
    {
        var map: [String:NamedReference] = [:]
        for (index, ref) in refs.enumerated() {
            guard let type = entityType(ref.type) else { preconditionFailure("Validation failed") }
            guard let idValue = identities[ref.id] else {
                throw DesignLoaderError.IndexedItemError(index, .unknownID(ref.id))
            }
            map[ref.name] = NamedReference(type: type, id: idValue)
        }
        return map
    }
    
    func makeNamedReferenceList(_ lists: [RawNamedList],
                                identities: IdentityResolution)
    throws (DesignLoaderError.IndexedItemError) -> [String:NamedReferenceList]
    {
        var result: [String:NamedReferenceList] = [:]
        
        for (listIndex, list) in lists.enumerated() {
            guard let type = entityType(list.itemType) else {
                throw DesignLoaderError.IndexedItemError(listIndex, .unknownEntityType(list.itemType))
            }
            
            var values: [EntityID.RawValue] = []
            
            for rawID in list.ids {
                guard let idValue = identities[rawID] else {
                    throw DesignLoaderError.IndexedItemError(listIndex, .unknownID(rawID))
                }
                values.append(idValue)
            }
            result[list.name] = NamedReferenceList(type: type, ids: values)
        }
        return result
    }
    
    func entityType(_ string: String) -> IdentityType? {
        // Note: This is version-dependent. Currently 0.0.1
        switch string {
        case "object": .object
        case "frame": .frame
        case "snapshot": .objectSnapshot
        default: nil
        }
    }

    internal func finaliseDesign(design: Design,
                                 namedReferences: ResolvedNamedReferences)
    throws (DesignLoaderError)
    {
        // Precondition: IDs must be validated
        if let list = namedReferences.systemLists["undo"] {
            guard list.type == .frame else {
                throw .design(.namedReferenceTypeMismatch("undo"))
            }
            let ids: [FrameID]  = list.typedIDs()
            design.undoList = ids
        }
        if let list = namedReferences.systemLists["redo"] {
            guard list.type == .frame else {
                throw .design(.namedReferenceTypeMismatch("redo"))
            }
            let ids: [FrameID]  = list.typedIDs()
            design.redoList = ids
        }
        if let ref = namedReferences.systemReferences["current_frame"] {
            guard ref.type == .frame else {
                throw .design(.namedReferenceTypeMismatch("current_frame"))
            }
            design.currentFrameID = FrameID(rawValue: ref.id)
        }

        // CurrentFrameID must be set when there is history.
        if design.currentFrame == nil
            && (!design.undoList.isEmpty || !design.redoList.isEmpty)
        {
            throw .design(.missingCurrentFrame)
        }

        for (name, ref) in namedReferences.userReferences {
            if ref.type == .frame {
                design.unsafeAssignName(name: name, frameID: FrameID(rawValue: ref.id))
            }
        }

    }
}
