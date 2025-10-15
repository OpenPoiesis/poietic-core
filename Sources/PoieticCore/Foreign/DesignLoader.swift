//
//  RawDesignLoader.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//

// TODO: [IMPORTANT] Split context into phases and remove all related precondition failures and fatal errors.

/// Error thrown by the design loader.
///
/// - SeeAlso: ``DesignLoader/load(_:into:)-6m9va``, ``DesignLoader/load(_:into:)-1o6qf``
///
public enum DesignLoaderError: Error, Equatable, CustomStringConvertible {
    
    /// Error with a snapshot. First item is an index of the offending snapshot, second item is the error.
    case snapshotError(Int, RawSnapshotError)

    /// Error with a frame. First item is an index of the offending frame, second item is the error.
    case frameError(Int, RawFrameError)

    /// Referencing raw object id provided as a name (a string) is not defined as any object or
    /// other design entity ID.
    case unknownNamedReference(String, ForeignEntityID)
    case invalidNamedReference(String)
    case unknownFrameID(ForeignEntityID)
    case missingCurrentFrame
    /// Duplicate frame ID.
    case duplicateFrame(FrameID)
    /// Duplicate snapshot ID.
    case duplicateSnapshot(ObjectSnapshotID)
    /// The loaded frame or collection of snapshots have broken structural integrity.
    ///
    /// - SeeAlso: ``Frame/validateStructure()``
    ///
    case brokenStructuralIntegrity(StructuralIntegrityError)
    
    public var description: String {
        switch self {
        case let .snapshotError(index, error):
            "Error in snapshot #\(index): \(error)"
        case let .frameError(index, error):
            "Error in frame #\(index): \(error)"
        case let .unknownNamedReference(name, id):
            "Unknown named reference \(name): \(id)"
        case let .invalidNamedReference(name):
            "Invalid named reference: \(name)"
        case let .duplicateFrame(id):
            "Duplicate frame ID: \(id)"
        case let .unknownFrameID(id):
            "Unknown frame ID: \(id)"
        case .missingCurrentFrame:
            "Missing current frame reference"
        case let .duplicateSnapshot(id):
            "Duplicate snapshot ID: \(id)"
        case let .brokenStructuralIntegrity(error):
            "Broken structural integrity: \(error)"
        }
    }
}

/// Error thrown by the design loader when there is an issue with an object snapshot.
///
public enum RawSnapshotError: Error, Equatable, CustomStringConvertible {
    /// Object ID or object snapshot ID has issues.
    case identityError(IdentityError)
    
    /// Object ID is provided, but can not be converted to internal ObjectID
    case invalidObjectID(ForeignEntityID)
    
    /// Object ID or snapshot ID is already used by another object or other design entity
    /// (such as frame).
    case duplicateID(ForeignEntityID)
    
    /// Object type is not provided.
    case missingObjectType
    
    /// There is no such object type in the associated metamodel.
    ///
    /// See: ``DesignLoader/metamodel``
    case unknownObjectType(String)
    
    /// Structural type is unknown or malformed.
    ///
    /// For example, an edge does not contain endpoint references.
    ///
    case invalidStructuralType
    
    /// Structural type of the raw object and the type object does not match.
    case structuralTypeMismatch(StructuralType)

    /// Referenced object does not exist within the reserved or required references.
    case unknownObjectID(ForeignEntityID) // referenced
    
    /// Parent of a snapshot with given index is not known within the frame.
    case unknownParent
    /// Children of a snapshot do not match previously resolved children of the same snapshot.
    case childrenMismatch

    public var description: String {
        switch self {
        case let .identityError(error):
            "Identity error: \(error)"
        case let .invalidObjectID(id):
            "Invalid object ID: '\(id)'"
        case let .duplicateID(id):
            "Duplicate ID: '\(id)'"
        case .missingObjectType:
            "Missing object type"
        case let .unknownObjectType(typeName):
            "Unknown object type name: '\(typeName)'"
        case .invalidStructuralType:
            "Invalid structural type"
        case let .structuralTypeMismatch(type):
            "Structural type mismatch. Expected: \(type)"
        case let .unknownObjectID(id):
            "Unknown object ID: '\(id)'"
        case .unknownParent:
            "Unknown parent"
        case .childrenMismatch:
            "Children do not match children of the snapshot in another frame"
        }
    }
}

/// Error thrown by the design loader when there is an issue with a raw frame.
///
public enum RawFrameError: Error, Equatable {
    /// Issue with frame ID.
    case identityError(IdentityError)
    
    /// Frame contains an unknown object.
    case unknownSnapshotID(ForeignEntityID)
    
    /// Parent of a snapshot with given index is not known within the frame.
    case unknownParent(Int)
    /// Children of a snapshot do not match previously resolved children of the same snapshot.
    case childrenMismatch(Int)
}


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
        let design: Design = Design(metamodel: metamodel)
        let context = LoadingContext(design: design, rawDesign: rawDesign)

        try validate(context)
        try reserveIdentities(context)
        try resolveObjectSnapshots(context)
        try resolveFrames(context)
        try resolveHierarchy(context: context)

        // 2. Validate user and system references
        let userReferences = try makeNamedReferences(rawDesign.userReferences, with: context)
        let systemReferences = try makeNamedReferences(rawDesign.systemReferences, with: context)
        // let userLists = try makeNamedReferenceList(rawDesign.userLists, with: reservation)
        let systemLists = try makeNamedReferenceList(rawDesign.systemLists, with: context)

        // 3. Create Snapshots
        // ----------------------------------------------------------------------
        try createSnapshots(context: context)

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
    
    internal func resolveObjectSnapshots(_ context: LoadingContext) throws (DesignLoaderError) {
        guard let snapshotIDs = context.snapshotIDs else { preconditionFailure("No snapshot IDs") }
        guard let objectIDs = context.objectIDs else { preconditionFailure("No object IDs") }

        precondition(context.phase == .identitiesReserved)
        assert(snapshotIDs.count == context.rawSnapshots.count)
        assert(snapshotIDs.count == objectIDs.count)
        
        var snapshots: [LoadingContext.ResolvedObjectSnapshot] = []
        
        for (i, rawSnapshot) in context.rawSnapshots.enumerated() {
            var refs: [ObjectID] = []
            
            for foreignRef in rawSnapshot.structure.references {
                guard let id: ObjectID = context.getID(foreignRef) else {
                    throw .snapshotError(i, .unknownObjectID(foreignRef))
                }
                refs.append(id)
            }

            let parentID: ObjectID?
            
            if let foreignParent = rawSnapshot.parent {
                guard let id: ObjectID = context.getID(foreignParent) else {
                    throw .snapshotError(i, .unknownObjectID(foreignParent))
                }
                parentID = id
            }
            else {
                parentID = nil
            }
            
            let snapshot = LoadingContext.ResolvedObjectSnapshot(
                snapshotID: snapshotIDs[i],
                objectID: objectIDs[i],
                structureReferences: refs,
                parent: parentID
            )
            snapshots.append(snapshot)
        }
        context.resolvedSnapshots = snapshots
        context.phase = .objectSnapshotsResolved
    }

    internal func resolveFrames(_ context: LoadingContext) throws (DesignLoaderError) {
        precondition(context.phase == .objectSnapshotsResolved)

        guard let frameIDs = context.frameIDs else { preconditionFailure("No frame IDs") }
        precondition(context.rawFrames.count == frameIDs.count)
        precondition(context.resolvedFrames == nil)
        
        var resolvedFrames: [LoadingContext.ResolvedFrame] = []
        for i in 0..<frameIDs.count {
            let frameID = frameIDs[i]
            let rawFrame = context.rawFrames[i]

            let indices: [Int]

            do {
                indices = try resolveFrame(rawFrame, in: context)
            }
            catch {
                throw .frameError(i, error)
            }
            let resolved = LoadingContext.ResolvedFrame(
                frameID: frameID,
                snapshotIndices: indices
            )
            resolvedFrames.append(resolved)
        }
        context.resolvedFrames = resolvedFrames
        context.phase = .framesResolved
    }
    
    /// - Returns: List of indices of object snapshots in the list of all snapshots.
    ///
    internal func resolveFrame(_ frame: RawFrame, in context: LoadingContext)
    throws (RawFrameError) -> [Int] {
        var indices: [Int] = []
        for foreignSnapshotID in frame.snapshots {
            guard let id: ObjectSnapshotID = context.getID(foreignSnapshotID) else {
                throw .unknownSnapshotID(foreignSnapshotID)
            }
            guard let index = context.snapshotIndex[id] else {
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
    internal func resolveHierarchy(context: LoadingContext) throws (DesignLoaderError) {
        precondition(context.phase == .framesResolved)
        guard let resolvedFrames = context.resolvedFrames
            else { preconditionFailure("Frames not resolved") }

        for (i, frame) in resolvedFrames.enumerated() {
            let indices = frame.snapshotIndices
            do {
                try resolveChildren(snapshotIndices: indices, context: context)
            }
            catch {
                throw .frameError(i, error)
            }
        }
        context.phase = .hierarchyResolved
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
    ///
    /// - Precondition: Parent object ID must exist within the snapshots referred to by ``snapshotIndices``.
    /// - Precondition: The snapshots must have unique both snapshot ID
    /// and object ID.
    ///
    internal func resolveChildren(snapshotIndices: [Int],
                                  context: LoadingContext)
    throws (RawFrameError) {
        precondition(context.phase == .objectSnapshotsResolved || context.phase == .framesResolved)
        guard let resolvedSnapshots = context.resolvedSnapshots
            else { preconditionFailure("Snapshots not resolved") }
        
        var objectToSnapshotIndex: [ObjectID:Int] = [:]
        var snapshotChildren: [Int:[ObjectID]] = [:]
        
        for index in snapshotIndices {
            let objectID = resolvedSnapshots[index].objectID
            if let dupeIndex = objectToSnapshotIndex[objectID] {
                let snapshot = resolvedSnapshots[dupeIndex]
                print("!!! DUPE SNAPSHOT FOR \(index)")
                print("!!!     dupe index       : \(dupeIndex)")
                print("!!!     dupe snapshot    : \(snapshot)")
                print("!!!     resolved snapshot: \(resolvedSnapshots[index])")
            }
            assert(objectToSnapshotIndex[objectID] == nil)
            objectToSnapshotIndex[objectID] = index
        }

        for childIndex in snapshotIndices {
            guard let parentObjectID = resolvedSnapshots[childIndex].parent else {
                continue
            }
            guard let parentIndex = objectToSnapshotIndex[parentObjectID] else {
                throw .unknownParent(childIndex)
            }
            let childObjectID = resolvedSnapshots[childIndex].objectID

            snapshotChildren[parentIndex, default: []].append(childObjectID)
        }

        // Validate and update resolved snapshots.
        //
        for snapshotIndex in snapshotIndices {
            let children: [ObjectID] = snapshotChildren[snapshotIndex] ?? []
            
            // Validate parents. Check whether previously resolved parent-children is the same
            // as the this one. It must be the same.
            // This error might happen when two raw frames have the same snapshot but the
            // children differ. Since the raw frame has only parent reference, this error is possible.
            //
            var copy = resolvedSnapshots[snapshotIndex]
            if let existingChildren = copy.children {
                guard existingChildren == children else {
                    throw .childrenMismatch(snapshotIndex)
                }
            }
            else {
                copy.children = children
                context.resolvedSnapshots?[snapshotIndex] = copy
            }
        }
    }
    
    /// Create snapshots from raw snapshots.
    ///
    /// Reservation is created using ``reserveIdentities(snapshots:with:)``.
    ///
    internal func createSnapshots(context: LoadingContext) throws (DesignLoaderError) {
        precondition(context.phase == .hierarchyResolved)
        
        guard let resolvedSnapshots = context.resolvedSnapshots else { preconditionFailure() }
        precondition(resolvedSnapshots.count == context.rawSnapshots.count)
        var result: [ObjectSnapshot] = []
        
        for (i, rawSnapshot) in context.rawSnapshots.enumerated() {
            let resolved = resolvedSnapshots[i]
            let snapshot: ObjectSnapshot

            do {
                snapshot = try create(rawSnapshot,
                                      snapshotID: resolved.snapshotID,
                                      objectID: resolved.objectID,
                                      parent: resolved.parent,
                                      children: resolved.children ?? [],
                                      context: context)
            }
            catch {
                throw .snapshotError(i, error)
            }
            
            result.append(snapshot)
        }
        context.objectSnapshots = result
        context.phase = .objectsCreated
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
    internal func create(_ rawSnapshot: RawSnapshot,
                       snapshotID: ObjectSnapshotID,
                       objectID: ObjectID,
                       parent: ObjectID?=nil,
                       children: [ObjectID] = [],
                       context: LoadingContext)
    throws (RawSnapshotError) -> ObjectSnapshot {
        // IMPORTANT: Sync the logic (especially preconditions) as in TransientFrame.create(...)
        // TODO: Consider moving this to Design (as well as its TransientFrame counterpart)
        guard let typeName = rawSnapshot.typeName else {
            throw .missingObjectType
        }
        guard let type = metamodel.objectType(name: typeName) else {
            throw .unknownObjectType(typeName)
        }
        
        let structure: Structure
        let references = rawSnapshot.structure.references
        switch rawSnapshot.structure.type {
        case .none:
            switch type.structuralType {
            case .unstructured: structure = .unstructured
            case .node: structure = .node
            default: throw .structuralTypeMismatch(type.structuralType)
            }
        case "unstructured":
            guard type.structuralType == .unstructured else {
                throw .structuralTypeMismatch(type.structuralType)
            }
            structure = .unstructured
        case "node":
            guard type.structuralType == .node else {
                throw .structuralTypeMismatch(type.structuralType)
            }
            structure = .node
        case "edge":
            guard type.structuralType == .edge else {
                throw .structuralTypeMismatch(type.structuralType)
            }
            guard references.count == 2 else {
                throw .invalidStructuralType
            }
            guard let origin: ObjectID = context.getID(references[0]) else {
                throw .unknownObjectID(references[0])
            }
            guard let target: ObjectID = context.getID(references[1]) else {
                throw .unknownObjectID(references[1])
            }
            structure = .edge(origin, target)
        default:
            throw .invalidStructuralType
        }
        
        var attributes: [String:Variant] = rawSnapshot.attributes
        if compatibilityVersion == Self.MakeshiftJSONLoaderVersion
            || (options.contains(.useIDAsNameAttribute)) {
            if let id = rawSnapshot.objectID,
               case let .string(name) = id,
               attributes["name"] == nil {
                attributes["name"] = Variant(name)
            }
        }
        
        // Set default attributes according to the type
        // TODO: Should this be here?
        for attribute in type.attributes {
            if attributes[attribute.name] == nil {
                attributes[attribute.name] = attribute.defaultValue
            }
        }
        
        let snapshot = ObjectSnapshot(type: type,
                                      snapshotID: snapshotID,
                                      objectID: objectID,
                                      structure: structure,
                                      parent: parent,
                                      children: children,
                                      attributes: attributes)
        return snapshot
    }
    
    func createFrames(in design: Design,
                      context: LoadingContext) throws (DesignLoaderError) {
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
    func makeNamedReferences(_ refs: [RawNamedReference], with context: LoadingContext)
        throws (DesignLoaderError) -> [String:NamedReference]
    {
        var map: [String:NamedReference] = [:]
        for ref in refs {
            guard let type = identityType(ref.type) else {
                throw .invalidNamedReference(ref.name)
            }
            guard let idValue = context.getID(ref.id, type: type) else {
                throw .unknownNamedReference(ref.name, ref.id)
            }
            map[ref.name] = NamedReference(type: type, id: idValue)
        }
        return map
    }
    
    func makeNamedReferenceList(_ lists: [RawNamedList],
                                with context: LoadingContext)
    throws (DesignLoaderError) -> [String:NamedReferenceList] {
        var result: [String:NamedReferenceList] = [:]
        for list in lists {
            guard let type = identityType(list.itemType) else {
                throw .invalidNamedReference(list.name)
            }

            var values: [EntityID.RawValue] = []

            for rawID in list.ids {
                guard let idValue = context.getID(rawID, type: type) else {
                    throw .unknownNamedReference(list.name, rawID)
                }
                values.append(idValue)
            }
            result[list.name] = NamedReferenceList(type: type, ids: values)
        }
        return result
    }
    
    func identityType(_ string: String) -> IdentityType? {
        // Note: This is version-dependent. Currently 0.0.1
        switch string {
        case "object": .object
        case "frame": .frame
        case "snapshot": .objectSnapshot
        default: nil
        }
    }
}


