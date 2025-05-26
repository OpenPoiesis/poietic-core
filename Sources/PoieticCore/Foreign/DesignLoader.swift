//
//  RawDesignLoader.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//

/**
 Edge cases
 
 - snapshot ID:
 - snapshot ID is provided but different type
 - snapshot ID not provided
 - snapshot ID is not convertible
 - snapshot ID is already taken
 - object ID:
 - object ID not provided
 - object ID is provided but different type
 - object ID  is not convertible
 
 */

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
    case unknownNamedReference(String, RawObjectID)
    case unknownFrameID(RawObjectID)
    case missingCurrentFrame
    /// Duplicate frame ID.
    case duplicateFrame(ObjectID)
    /// Duplicate snapshot ID.
    case duplicateSnapshot(ObjectID)
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
    case identityError(RawIdentityError)
    
    /// Object ID is provided, but can not be converted to internal ObjectID
    case invalidObjectID(RawObjectID)
    
    /// Object ID or snapshot ID is already used by another object or other design entity
    /// (such as frame).
    case duplicateID(RawObjectID)
    
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
    case unknownObjectID(RawObjectID) // referenced

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
        }
    }
}

/// Error thrown by the design loader when there is an issue with a raw frame.
///
public enum RawFrameError: Error, Equatable {
    /// Issue with frame ID.
    case identityError(RawIdentityError)

    /// Frame contains an unknown object.
    case unknownSnapshotID(RawObjectID)
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
    // TODO: Rename just to DesignLoader, "raw" is assumed
    
    public let metamodel: Metamodel
    let compatibilityVersion: SemanticVersion?
    static let MakeshiftJSONLoaderVersion = SemanticVersion(0, 0, 1)
    public let options: Options
    
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
        
        // 1. Reserve identities
        // ----------------------------------------------------------------------
        var reservation = IdentityReservation(design: design)
        try reserveIdentities(snapshots: rawDesign.snapshots, with: &reservation)
        try reserveIdentities(frames: rawDesign.frames, with: &reservation)

        // 2. Validate user and system references
        let userReferences = try makeNamedReferences(rawDesign.userReferences, with: reservation)
        let systemReferences = try makeNamedReferences(rawDesign.systemReferences, with: reservation)
        // let userLists = try makeNamedReferenceList(rawDesign.userLists, with: reservation)
        let systemLists = try makeNamedReferenceList(rawDesign.systemLists, with: reservation)

        // 3. Create Snapshots
        // ----------------------------------------------------------------------
        let snapshots = try create(snapshots: rawDesign.snapshots, reservation: reservation)

        // 4. Load (commit)
        
        try load(into: design,
                 frames: rawDesign.frames,
                 snapshots: snapshots,
                 reservation: &reservation)
        
        // 5. Post-process
        design.undoableFrames = systemLists["undo"]?.ids ?? []
        design.redoableFrames = systemLists["redo"]?.ids ?? []
        design.currentFrameID = systemReferences["current_frame"]?.id
        // Consistency check: currentFrameID must be set when there is history.
        if design.currentFrame == nil
            && (!design.undoableFrames.isEmpty || !design.redoableFrames.isEmpty) {
            fatalError("currentFrameIDNotSet")
        }

        for (name, ref) in userReferences {
            if ref.type == "frame" {
                design._namedFrames[name] = design.frame(ref.id)
            }
        }
        
        return design
    }
    
    /// Load raw snapshots into a transient frame.
    ///
    /// This method is intended to be used when importing external frames or for pasting in the
    /// Copy & Paste mechanism.
    ///
    /// Process:
    ///
    /// 1. Reserve snapshot identities.
    /// 2. Validate structural integrity of the snapshots within the context of the frame.
    ///
    public func load(_ rawSnapshots: [RawSnapshot], into frame: TransientFrame) throws (DesignLoaderError) {
        var reservation = IdentityReservation(design: frame.design)
        try createIdentities(snapshots: rawSnapshots, with: &reservation)
        let snapshots = try create(snapshots: rawSnapshots, reservation: reservation)

        for snapshot in snapshots {
            frame.unsafeInsert(snapshot)
        }

        do {
            try frame.validateStructure()
        }
        catch {
            throw .brokenStructuralIntegrity(error)
        }

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
        // FIXME: [WIP] [IMPORTANT] Use this instead of load(_ rawSnapshots:,into:)
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
    /// Method that reserves identities for snapshots.
    ///
    /// For each snapshot, an identity is reserved using the ``IdentityManager`` of the design.
    ///
    /// - Snapshot ID:
    ///     - some provided: ID will be reserved if available, if not then duplicate error is thrown.
    ///     - `nil`: New ID will be created and reserved, snapshot will be considered an orphan.
    /// - Object ID:
    ///     - some provided: ID will be reserved if available. If it is already used, it must be
    ///       an object ID, otherwise type mismatch error is thrown.
    ///     - `nil`: New ID will be created and reserved.
    ///
    /// You typically do not need to call this method, it is called in ``load(_:)``
    /// and ``load(_:into:)-1o6qf``. It is provided for more customised loading.
    ///
    /// ## Orphans
    ///
    /// If ID is not provided, it will be generated. However, that object is considered an orphan
    /// and it will not be able to refer to it from other entities.
    ///
    /// Orphaned snapshots will be ignored. Objects with orphaned object identity will be preserved.
    ///
    public func reserveIdentities(snapshots rawSnapshots: [RawSnapshot],
                                  with reservation: inout IdentityReservation)
    throws (DesignLoaderError) {
//        var reservation = IdentityReservation(design: design)
        // 1. Allocate snapshot IDs
        // ----------------------------------------------------------------
        for (i, rawSnapshot) in rawSnapshots.enumerated() {
            do {
                try reservation.reserve(snapshotID: rawSnapshot.snapshotID,
                                        objectID: rawSnapshot.id)
            }
            catch {
                throw .snapshotError(i, .identityError(error))
            }
        }
    }
    /// Create identities for a batch of snapshots.
    ///
    /// The identities provided in the raw snapshots are used only for references within the batch,
    /// they will not be preserved.
    ///
    public func createIdentities(snapshots rawSnapshots: [RawSnapshot],
                                 with reservation: inout IdentityReservation)
    throws (DesignLoaderError) {
        for rawSnapshot in rawSnapshots {
            reservation.create(snapshotID: rawSnapshot.snapshotID, objectID: rawSnapshot.id)
        }
    }

    /// Reserve identities of frames.
    ///
    ///
    public func reserveIdentities(frames rawFrames: [RawFrame],
                                  with reservation: inout IdentityReservation)
    throws (DesignLoaderError) {
        // TODO: Rename to be generic reservation of id list
        for (i, rawFrame) in rawFrames.enumerated() {
            do {
                try reservation.reserve(frameID: rawFrame.id)
            }
            catch {
                throw .frameError(i, .identityError(error))
            }
        }
    }
    /// Create snapshots from raw snapshots.
    ///
    /// Reservation is created using ``reserveIdentities(snapshots:with:)``.
    ///
    public func create(snapshots rawSnapshots: [RawSnapshot],
                       reservation: borrowing IdentityReservation) throws (DesignLoaderError) -> SnapshotStorage {
        let result = SnapshotStorage()
        
        for (i, rawSnapshot) in rawSnapshots.enumerated() {
            let (snapshotID, objectID) = reservation.snapshots[i]
            let snapshot: ObjectSnapshot
            
            do {
                snapshot = try create(rawSnapshot, id: objectID, snapshotID: snapshotID, reservation: reservation)
            }
            catch {
                throw .snapshotError(i, error)
            }
            
            result.insertOrRetain(snapshot)
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
    public func create(_ rawSnapshot: RawSnapshot,
                       id objectID: ObjectID,
                       snapshotID: ObjectID,
                       reservation: borrowing IdentityReservation)
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
            guard let origin = reservation[references[0]], origin.type == .object else {
                throw .unknownObjectID(references[0])
            }
            guard let target = reservation[references[1]], target.type == .object else {
                throw .unknownObjectID(references[1])
            }
            structure = .edge(origin.id, target.id)
        default:
            throw .invalidStructuralType
        }
        
        let parent: ObjectID?
        if let rawParent = rawSnapshot.parent {
            guard let res = reservation[rawParent], res.type == .object else {
                throw .unknownObjectID(rawParent)
            }
            parent = res.id
        }
        else {
            parent = nil
        }
        
        var attributes: [String:Variant] = rawSnapshot.attributes
        if compatibilityVersion == Self.MakeshiftJSONLoaderVersion
            || (options.contains(.useIDAsNameAttribute)) {
            if let id = rawSnapshot.id,
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
                                      attributes: attributes)
        return snapshot
    }
    
    func load(into design: Design,
              frames rawFrames: [RawFrame],
              snapshots: SnapshotStorage,
              reservation: inout IdentityReservation) throws (DesignLoaderError) {
        var frames: [StableFrame] = []
        let usedSnapshots = SnapshotStorage()
        
        for (i, rawFrame) in rawFrames.enumerated() {
            let frame: StableFrame
            let frameID = reservation.frames[i]
            guard !design.containsFrame(frameID) else {
                throw .duplicateFrame(frameID)
            }
            do {
                frame = try create(frame: rawFrame,
                                   id: frameID,
                                   snapshots: snapshots,
                                   for: design,
                                   reservation: reservation)
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
            for snapshot in frame.snapshots {
                usedSnapshots.insertOrRetain(snapshot)
            }
            frames.append(frame)
        }
        for frame in frames {
            design.unsafeInsert(frame)
        }
        design.identityManager.use(reserved: reservation.reserved)
        reservation.removeAll()
    }
    // TODO: Add validation (validateStructure())
    func create(frame rawFrame: RawFrame,
                id frameID: ObjectID,
                snapshots: SnapshotStorage,
                for design: Design,
                reservation: borrowing IdentityReservation) throws (RawFrameError) -> StableFrame {
        var frameSnapshots: [ObjectSnapshot] = []
        for rawSnapshotID in rawFrame.snapshots {
            guard let snapshotRes = reservation[rawSnapshotID], snapshotRes.type == .snapshot else {
                throw .unknownSnapshotID(rawSnapshotID)
            }
            guard let snapshot = snapshots[snapshotRes.id] else {
                throw .unknownSnapshotID(rawSnapshotID)
            }
            frameSnapshots.append(snapshot)
        }
        let frame = StableFrame(design: design, id: frameID, snapshots: frameSnapshots)
        return frame
    }
    
    struct NamedReference {
        public let type: String
        let id: ObjectID
    }
    struct NamedReferenceList {
        let type: String
        let ids: [ObjectID]
    }
    func makeNamedReferences(_ refs: [RawNamedReference],
                             with reservation: borrowing IdentityReservation)
    throws (DesignLoaderError) -> [String:NamedReference] {
        var map: [String:NamedReference] = [:]
        for ref in refs {
            guard let idRes = reservation[ref.id] else {
                throw .unknownNamedReference(ref.name, ref.id)
            }
            map[ref.name] = NamedReference(type: ref.type, id: idRes.id)
        }
        return map
    }
    func makeNamedReferenceList(_ lists: [RawNamedList],
                                with reservation: borrowing IdentityReservation)
    throws (DesignLoaderError) -> [String:NamedReferenceList] {
        var result: [String:NamedReferenceList] = [:]
        for list in lists {
            var ids: [ObjectID] = []
            for rawID in list.ids {
                guard let idRes = reservation[rawID] else {
                    throw .unknownNamedReference(list.name, rawID)
                }
                ids.append(idRes.id)
            }
            result[list.name] = NamedReferenceList(type: list.itemType, ids: ids)
        }
        return result
    }
}


