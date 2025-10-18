//
//  RawDesignLoader.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//

/*

 Loader versions:
 
 0.0.1:
    - allow names as IDs
 0.1.0:
    - do not allow names as IDs
 
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

        let loadingContext = try validate(
            rawDesign: rawDesign,
            identityManager: design.identityManager
        )
        let identityResolution = try resolveIdentities(
            context: loadingContext,
            identityStrategy: .requireProvided
        )
        
        let resolvedSnapshots = try resolveObjectSnapshots(
            context: loadingContext,
            identities: identityResolution,
        )
        // We have:
        // - no duplicate snapshot IDs
        // - well-formed snapshot data
        
        let resolvedFrames = try resolveFrames(
            context: loadingContext,
            identities: identityResolution,
        )
        // We have:
        // - referenced snapshots exist
        // - there are no duplicate object IDs within frame
        let resolvedHierarchy  = try resolveHierarchy(
            frames: resolvedFrames,
            objectSnapshots: resolvedSnapshots,
            identities: identityResolution
        )
        // Parent reference (if present) points to objectID that exists in same frame
        // All children references point to objectIDs that exist in same frame
        // Bidirectional consistency: if A has child B, then B has parent A

        
        // 3. Create Snapshots
        // ----------------------------------------------------------------------
        try createSnapshots(resolvedSnapshots: resolvedSnapshots,
                            children: resolvedHierarchy)

        // 4. Load (commit)
        
        try createFrames(in: design, context: context)
        // 5. Post-process
        if let list = systemLists["undo"] {
            guard list.type == .frame else {
                throw .invalidNamedReference("undo")
            }
            let ids: [FrameID]  = list.typedIDs()
            design.undoList = ids
        }
        if let list = systemLists["redo"] {
            guard list.type == .frame else {
                throw .invalidNamedReference("redo")
            }
            let ids: [FrameID]  = list.typedIDs()
            design.redoList = ids
        }
        if let ref = systemReferences["current_frame"] {
            guard ref.type == .frame else {
                throw .invalidNamedReference("current_frame")
            }
            design.currentFrameID = FrameID(rawValue: ref.id)
        }

        // CurrentFrameID must be set when there is history.
        if design.currentFrame == nil
            && (!design.undoList.isEmpty || !design.redoList.isEmpty) {
            throw .missingCurrentFrame
        }

        for (name, ref) in userReferences {
            if ref.type == .frame {
                context.design._namedFrames[name] = design.frame(FrameID(rawValue: ref.id))
            }
        }
        design.identityManager.use(reserved: context.reserved)

        return context.design
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
    public func load(_ design: RawDesign, into frame: TransientFrame) throws (DesignLoaderError) {
        var snapshots: [RawSnapshot] = []
        
        if let currentFrameID = design.currentFrameID {
            guard let currentFrame = design.frames.first(where: { $0.id == currentFrameID }) else {
                throw .unknownFrameID(currentFrameID)
            }
            
            for (i, id) in currentFrame.snapshots.enumerated() {
                guard let snapshot = design.first(snapshotWithID: id) else {
                    throw .snapshotError(i, .unknownObjectID(id))
                }
                snapshots.append(snapshot)
            }
        }
        else {
            guard design.frames.isEmpty else {
                throw .missingCurrentFrame
            }
            snapshots = design.snapshots
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
        let rawDesign = RawDesign(snapshots: rawSnapshots)
        let context = LoadingContext(design: frame.design,
                                     rawDesign: rawDesign,
                                     identityStrategy: identityStrategy,
                                     unavailable: Set(frame.objectIDs))
        
        try validate(context)
        try reserveIdentities(context)
        try resolveObjectSnapshots(context)
        guard let resolvedSnapshots = context.resolvedSnapshots
            else { preconditionFailure("Snapshots not resolved") }

        do {
            let indices = Array<Int>(resolvedSnapshots.indices)
            try resolveChildren(snapshotIndices: indices, context: context)
        }
        catch .unknownParent(let index) {
            throw .snapshotError(index, .unknownParent)
        }
        catch .childrenMismatch(let index) {
            throw .snapshotError(index, .childrenMismatch)
        }
        catch {
            fatalError("Unexpected error: \(error)")
        }
        
        try createSnapshots(context: context)
        guard let objectSnapshots = context.objectSnapshots else { fatalError() }

        frame.unsafeInsert(objectSnapshots, reservations: context.reserved)
        
        do {
            // TODO: [WIP] Is this needed?
            try frame.validateStructure()
        }
        catch {
            throw .brokenStructuralIntegrity(error)
        }
        return objectSnapshots.map { $0.objectID }
    }
    

    internal func resolveFrames(context: ValidatedLoadingContext,
                                identities: IdentityResolution)
        throws (DesignLoaderError) -> [ResolvedFrame]
    {
        precondition(context.rawFrames.count == identities.frameIDs.count)

        var resolvedFrames: [ResolvedFrame] = []
        
        var frameIndex = 0
        for (frameID, rawFrame) in zip(identities.frameIDs, context.rawFrames) {
            let indices: [Int]

            do {
                indices = try resolveFrame(rawFrame, identities: identities)
            }
            catch {
                throw .item(.frames, frameIndex, error)
            }
            let resolved = ResolvedFrame(frameID: frameID, snapshotIndices: indices)
            resolvedFrames.append(resolved)
            frameIndex += 1
        }
        
        return resolvedFrames
    }
    
    /// - Returns: List of indices of object snapshots in the list of all snapshots.
    ///
    internal func resolveFrame(_ frame: RawFrame, identities: IdentityResolution)
    throws (DesignLoaderError.ItemError) -> [Int]
    {
        var indices: [Int] = []
        for foreignSnapshotID in frame.snapshots {
            guard let id: ObjectSnapshotID = identities[foreignSnapshotID] else {
                throw .unknownSnapshotID(foreignSnapshotID)
            }
            guard let index = identities.snapshotIndex[id] else {
                // HINT: See reservation (phase) of IDs if this happens.
                fatalError("Broken snapshot index")
            }
            indices.append(index)
        }
        return indices
    }

    /// Resolve parent-child hierarchy of object snapshots.
    ///
    /// The method requires the frames to be resolved.
    internal func resolveHierarchy(frames: [ResolvedFrame],
                                   objectSnapshots: [ResolvedObjectSnapshot],
                                   identities: IdentityResolution)
    throws (DesignLoaderError) -> [Int:[ObjectID]]
    {
        var allChildrenMap: [Int:[ObjectID]] = [:] // All children resolved
        
        for (frameIndex, frame) in frames.enumerated() {
            let resolvedMap: [Int:[ObjectID]] // Children resolved within frame
            
            do {
                resolvedMap = try resolveChildren(
                    snapshotIndices: frame.snapshotIndices,
                    objectSnapshots: objectSnapshots)
            }
            catch {
                throw .item(.objectSnapshots, error.index, error.error)
            }
            
            // Integrity check: validate created children lists whether they match
            // existing children list.
            for (index, resolved) in resolvedMap {
                if let existing = allChildrenMap[index] {
                    guard existing == resolved else {
                        throw .item(.frames, frameIndex, .childrenMismatch)
                    }
                }
                else {
                    allChildrenMap[index] = resolved
                }
            }
        }
        return allChildrenMap
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
    /// - Throws an error with offending snapshot index.
    ///
    internal func resolveChildren(snapshotIndices: [Int],
                                  objectSnapshots: [ResolvedObjectSnapshot])
    throws (DesignLoaderError.IndexedItemError) -> [Int:[ObjectID]]
    {
        // TODO: Consider using SnapshotIDs instead of indices
        // TODO: Reconsider this needed to be in the loader. Move to the transient frame.
        var objectToSnapshotIndex: [ObjectID:Int] = [:]
        var resolvedMap: [Int:[ObjectID]] = [:]
        
        for index in snapshotIndices {
            let snapshot = objectSnapshots[index]
            assert(objectToSnapshotIndex[snapshot.objectID] == nil)
            objectToSnapshotIndex[snapshot.objectID] = index
        }

        for childIndex in snapshotIndices {
            guard let parentObjectID = objectSnapshots[childIndex].parent else {
                continue
            }
            guard let parentIndex = objectToSnapshotIndex[parentObjectID] else {
                throw DesignLoaderError.IndexedItemError(childIndex, .unknownParent)
            }
            let childObjectID = objectSnapshots[childIndex].objectID

            resolvedMap[parentIndex, default: []].append(childObjectID)
        }

        return resolvedMap
    }
    
    
    func createFrames(in design: Design,
                      context: LoadingContext)
    throws (DesignLoaderError) {
        guard let resolvedFrames = context.resolvedFrames else { preconditionFailure() }
        var frames: [DesignFrame] = []
        
        for (i, resolvedFrame) in resolvedFrames.enumerated() {
            let frame: DesignFrame
            guard !design.containsFrame(resolvedFrame.frameID) else {
                // FIXME: [WIP] This should be a fatal error -> we did not resolve correctly
                throw .duplicateFrame(resolvedFrame.frameID)
            }
            do {
                frame = try createFrame(id: resolvedFrame.frameID,
                                        snapshotIndices: resolvedFrame.snapshotIndices,
                                        context: context)
            }
            catch {
                throw .frameError(i, error)
            }
            do {
                try frame.validateStructure()
            }
            catch {
                throw .brokenStructuralIntegrity(error)
            }
            frames.append(frame)
        }
        for frame in frames {
            design.unsafeInsert(frame)
        }
    }

    // TODO: Add validation (validateStructure())
    func createFrame(id designID: FrameID,
                     snapshotIndices: [Int],
                     context: LoadingContext) throws (RawFrameError) -> DesignFrame {
        guard let allSnapshots = context.objectSnapshots else { preconditionFailure() }

        let frameSnapshots = snapshotIndices.map { allSnapshots[$0] }
        let frame = DesignFrame(design: context.design, id: designID, snapshots: frameSnapshots)
        return frame
    }
    
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
}
