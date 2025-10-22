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


/// Object that loads raw representation of design or raw object snapshots into a design.
///
/// The design loader is the primary way of constructing whole design or its components from
/// foreign representations that were converted into raw design entities
/// (``RawSnapshot``, ``RawFrame``, ``RawDesign``, ...).
///
/// The typical application use-cases for the design loader are:
///
/// - Create a design from an external representation such as a file. See ``JSONDesignReader`` and
///   ``load(_:)``.
/// - Import from another design. See ``load(_:into:)-(RawDesign,_)``.
/// - Paste from a pasteboard during Copy & Paste operation. See ``load(_:into:)-([RawSnapshot],_)``,
///   and ``JSONDesignWriter``.
///
/// The main responsibilities of the deign loader are:
///
/// - Validation of raw design
/// - Reservation of object identities.
/// - Resolution of entity references
/// - Creation of entities (object snapshots, frames, ...)
///
public class DesignLoader {
    /// Metamodel that is used for lookup and validation during loading process.
    ///
    /// Main uses of metamodel in the design loader:
    ///
    /// - Assigning object types to object snapshots based on object type name.
    /// - Providing default attribute values.
    /// - Determining default structural type
    ///
    public let metamodel: Metamodel
    
    let compatibilityVersion: SemanticVersion?
    static let MakeshiftJSONLoaderVersion = SemanticVersion(0, 0, 1)
    
    /// Options to control the loading process.
    public let options: Options
    
    /// Strategy how identities are reserved when loading the raw design.
    ///
    /// For example, when pasting from a pasteboard, we want to preserve if possible and
    /// create new so we do not cause conflicts.
    ///
    /// ```swift
    /// let rawDesign: RawDesign  // Raw design we decoded from pasteboard
    /// let trans: TransientFrame // Transaction into which we "paste"
    /// let loader = DesignLoader(metamodel: StockFlowMetamodel)
    ///
    /// try loader.load(rawDesign, identityStrategy: .preserveOrCreate)
    /// ```
    ///
    public enum IdentityStrategy {
        /// Loading operation requires that all provided identities are preserved.
        ///
        /// Typical use-case is restoration of a whole design.
        case requireProvided
        
        // Identities are preserved, if they are available. Otherwise new identities will be
        // created. Typical use case is pasting from a pasteboard or importing into existing frame.
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
    
    /// Create a design loader for design that conform to given metamodel.
    ///
    public init(metamodel: Metamodel, options: Options = Options(), compatibilityVersion version: SemanticVersion? = nil) {
        self.metamodel = metamodel
        self.compatibilityVersion = version
        self.options = options
    }

    // MARK: - Loading
    
    /// Loads a raw design and creates new design.
    ///
    /// The loader goes through following process:
    ///
    /// 1. Validate the raw design for duplicates.
    /// 2. Reserve identities.
    /// 2. Create snapshots and frames.
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
        
        let hierarchicalSnapshots  = try resolveHierarchy(
            frameResolution: frameResolution,
            snapshotResolution: partialSnapshotResolution
        )
        
        let snapshots = try createSnapshots(resolution: hierarchicalSnapshots)

        var snapshotMap: [ObjectSnapshotID:ObjectSnapshot] = [:]
        for snapshot in snapshots {
            snapshotMap[snapshot.snapshotID] = snapshot
        }
        
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
    /// This is used for foreign design imports and for performing paste from a pasteboard
    /// (clipboard).
    ///
    /// Requirements for the raw design:
    ///
    /// - If the raw design has one or more frames, then current frame must be set and that frame will be loaded.
    /// - If the raw design has no frames: All snapshots will be treated as snapshot of a single frame.
    ///
    /// - SeeAlso: ``load(_:into:)-1o6qf``
    ///
    public func load(_ rawDesign: RawDesign, into frame: TransientFrame) throws (DesignLoaderError) {
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
    /// This method is intended to be used when importing external frames or for pasting in the
    /// Copy & Paste mechanism.
    ///
    /// - Parameters:
    ///     - rawSnapshots: List of raw snapshots to be loaded into the frame.
    ///     - frame: Frame into which the object snapshots will be loaded.
    ///     - identityStrategy: Strategy used to generate or preserve provided raw IDs.
    ///       Recommended to use ``IdentityStrategy/preserveOrCreate`` strategy.
    ///
    /// - Returns: List of object IDs of inserted object snapshots. Caller might do adjustments
    ///   to the imported snapshots, for example offset their location on consecutive paste
    ///   operation.
    ///
    /// Loading process:
    ///
    /// 1. Validate snapshots for duplicate IDs.
    /// 2. Reserve identities according to provided ``IdentityStrategy``.
    /// 3. Resolve snapshot references.
    /// 4. Resolve snapshot hierarchy.
    /// 5. Create object snapshot instances.
    /// 6. Insert snapshots into frame.
    ///
    /// - Note: The references of ``rawSnapshots`` are resolved _only_ within the provided object
    ///  snapshots. Any references from ``rawSnapshots`` that are not contained in the input
    ///  parameter are considered invalid. As a consequence, there can not be references to existing
    ///  objects in the ``frame``.
    ///
    @discardableResult
    internal func load(_ rawSnapshots: [RawSnapshot],
                       into frame: TransientFrame,
                       identityStrategy: IdentityStrategy = .requireProvided)
    throws (DesignLoaderError) -> [ObjectID] {
        let identityResolution: DesignLoader.IdentityResolution
        
        let rawDesign = RawDesign(snapshots: rawSnapshots)

        let validationResolution = try validate(
            rawDesign: rawDesign,
            identityManager: frame.design.identityManager
        )
        
        // FIXME: [IMPORTANT] Release reservations from here:
        identityResolution = try resolveIdentities(
            resolution: validationResolution,
            identityStrategy: identityStrategy
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
        
        // FIXME: [IMPORTANT] Release reservations above ^^ to here.

        frame.unsafeInsert(snapshots, reservations: completeSnapshots.identities.reserved)
        
        do {
            // TODO: [WIP] Is this needed? The caller is validating the frame anyway before accept().
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
        var seenObjects: Set<ObjectID> = []

        for foreignSnapshotID in frame.snapshots {
            guard let snapshotID: ObjectSnapshotID = identities[foreignSnapshotID] else {
                throw .unknownSnapshotID(foreignSnapshotID)
            }

            // Check for duplicate objects (same object with different snapshots in one frame)
            // Get objectID using the snapshot index
            guard let index = identities.snapshotIndex[snapshotID] else {
                preconditionFailure("Snapshot ID must be in index")
            }
            let objectID = identities.objectIDs[index]

            if seenObjects.contains(objectID) {
                throw .duplicateObject(foreignSnapshotID)
            }
            seenObjects.insert(objectID)

            ids.append(snapshotID)
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
        // Map of all snapshots in all frames. `nil` means "Snapshot was considered but has
        // no children". Empty array should not happen.
        var allChildrenMap: [ObjectSnapshotID:[ObjectID]?] = [:]
        
        for (frameIndex, frame) in frameResolution.frames.enumerated() {
            let frameChildrenMap: [ObjectSnapshotID:[ObjectID]] // Children resolved within frame
            let snapshots: [ResolvedObjectSnapshot] = frame.snapshots.compactMap {
                snapshotResolution[$0]
            }
            precondition(snapshots.count == frame.snapshots.count, "Broken snapshot resolution")
            
            do {
                frameChildrenMap = try resolveChildren(
                    snapshots: snapshots,
                    snapshotResolution: snapshotResolution
                )
            }
            catch {
                throw .item(.objectSnapshots, error.index, error.error)
            }
            
            
            for snapshotID in frame.snapshots {
                let children = frameChildrenMap[snapshotID]
                if let seen = allChildrenMap[snapshotID], seen != children {
                    throw .item(.frames, frameIndex, .childrenMismatch)
                }
                allChildrenMap[snapshotID] = children
            }
        }
        
        
        return SnapshotHierarchyResolution(
            objectSnapshots: snapshotResolution.objectSnapshots,
            children: allChildrenMap.compactMapValues { $0 },
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
        assert(childrenMap.values.allSatisfy { !$0.isEmpty })
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
        rawDesign: RawDesign,
        identities: IdentityResolution
    )
    throws (DesignLoaderError) -> ResolvedNamedReferences
    {
        // FIXME: [IMPORTANT] We need guarantee that the raw design corresponds to the identity reservations
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
