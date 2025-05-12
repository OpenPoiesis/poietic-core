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

public enum RawDesignEntity {
    case snapshot
    case frame
    case systemNamedReference
    case systemNamedList
    case userNamedReference
    case userNamedList
}

public enum RawDesignLoaderError: Error, Equatable {
    case snapshotError(Int, RawSnapshotError)
    case frameError(Int, RawFrameError)
    case unknownNamedReference(String, RawObjectID)
    case transactionError(TransactionError)
}


// RawSnapshotError
public enum RawSnapshotError: Error, Equatable {
    case identityError(RawIdentityError)
    
    case invalidObjectID(RawObjectID)
    case duplicateID(RawObjectID)
    case missingObjectType
    case unknownObjectType(String)
    case invalidStructuralType
    // TODO: Is this used in identity error?
    case unknownObjectID(RawObjectID) // referenced
}
public enum RawFrameError: Error, Equatable {
//    case invalidObjectID(RawObjectID)
    case identityError(RawIdentityError)
//    case missingObjectType
//    case unknownObjectType(String)
//    case invalidStructure
    case unknownSnapshotID(RawObjectID) // referenced
}
// TODO: [WIP] Loaded batch must refer to IDs only within the batch, not outside

public class RawDesignLoader {
    let metamodel: Metamodel
    let compatibilityVersion: SemanticVersion?
    static let MakeshiftJSONLoaderVersion = SemanticVersion(0, 0, 1)
    let options: Options
    
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
        public static let nameFromID = Options(rawValue: 1 << 0)
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
    public func load(_ rawDesign: RawDesign) throws (RawDesignLoaderError) -> Design {
        let design: Design = Design(metamodel: metamodel)
        
        // 1. Reserve identities
        // ----------------------------------------------------------------------
        var reservation = IdentityReservation(design: design)
        try reserveIdentities(snapshots: rawDesign.snapshots, with: &reservation)
        try reserveIdentities(frames: rawDesign.frames, with: &reservation)

        // 2. Validate user and system references
        let userReferences = try makeNamedReferences(rawDesign.userReferences, with: reservation)
        let systemReferences = try makeNamedReferences(rawDesign.systemReferences, with: reservation)
        let userLists = try makeNamedReferenceList(rawDesign.userLists, with: reservation)
        let systemLists = try makeNamedReferenceList(rawDesign.systemLists, with: reservation)

        // TODO: Validate undo/redo is frame list
        // TODO: Validate current_frame is frame
        
        // 3. Create transaction
        // ----------------------------------------------------------------------
        let trans = AppendingTransaction(design)
        try load(snapshots: rawDesign.snapshots, in: trans, reservation: reservation)
        try load(frames: rawDesign.frames, in: trans, reservation: reservation)
        // 4. Apply
        // ----------------------------------------------------------------------
        do {
            try design.accept(appending: trans)
        }
        catch {
            throw .transactionError(error)
        }
        
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
    
    /// Load
    ///
    public func load(_ rawDesign: RawDesign, into frame: TransientFrame) throws (RawDesignLoaderError) {
        // FIXME: [WIP] rename makeshiftLoad or load(snapshotsFrom:into:) something
        // FIXME: [WIP] add which frame to load
        // FIXME: [WIP] what to do on dupes?
        let trans = AppendingTransaction(frame.design)

        var reservation = IdentityReservation(design: frame.design)
        try reserveIdentities(snapshots: rawDesign.snapshots, with: &reservation)
        try load(snapshots: rawDesign.snapshots, in: trans, reservation: reservation)

        for snapshot in trans.snapshots {
            frame.unsafeInsert(snapshot)
        }
        
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
    /// ## Orphans
    ///
    /// If ID is not provided, it will be generated. However, that object is considered an orphan
    /// and it will not be able to refer to it from other entities.
    ///
    /// Orphaned snapshots will be ignored. Objects with orphaned object identity will be preserved.
    ///
    func reserveIdentities(snapshots rawSnapshots: [RawSnapshot],
                           with reservation: inout IdentityReservation)
    throws (RawDesignLoaderError) {
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
    func reserveIdentities(frames rawFrames: [RawFrame],
                           with reservation: inout IdentityReservation)
    throws (RawDesignLoaderError) {
//        var reservation = IdentityReservation(design: design)
        // 1. Allocate snapshot IDs
        // ----------------------------------------------------------------
        for (i, rawFrame) in rawFrames.enumerated() {
            do {
                try reservation.reserve(frameID: rawFrame.id)
            }
            catch {
                throw .frameError(i, .identityError(error))
            }
        }
    }

    func load(snapshots rawSnapshots: [RawSnapshot],
              in trans: AppendingTransaction,
              reservation: borrowing IdentityReservation) throws (RawDesignLoaderError) {
        for (i, rawSnapshot) in rawSnapshots.enumerated() {
            let (snapshotID, objectID) = reservation.snapshots[i]
            let snapshot: DesignObject
            
            do {
                snapshot = try create(rawSnapshot, id: objectID, snapshotID: snapshotID, reservation: reservation)
            }
            catch {
                throw .snapshotError(i, error)
            }
            
            trans.insert(snapshot)
        }
    }
    
    func create(_ rawSnapshot: RawSnapshot, id objectID: ObjectID, snapshotID: ObjectID, reservation: borrowing IdentityReservation) throws (RawSnapshotError) -> DesignObject {
        guard let typeName = rawSnapshot.typeName else {
            throw .missingObjectType
        }
        guard let type = metamodel.objectType(name: typeName) else {
            throw .unknownObjectType(typeName)
        }
        
        // FIXME: [WIP] What about type <-> structure mismatch?
        let structure: Structure
        let references = rawSnapshot.structure.references
        switch rawSnapshot.structure.type {
        case .none: structure = .unstructured
        case "unstructured": structure = .unstructured
        case "node": structure = .node
        case "edge":
            guard references.count == 2 else {
                // TODO: [WIP] Throw structural type mismatch
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
            // TODO: Strategy: unknownAsUnstructured
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
            || (options.contains(.nameFromID)) {
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
        
        let snapshot = DesignObject(id: objectID,
                                    snapshotID: snapshotID,
                                    type: type,
                                    structure: structure,
                                    parent: parent,
                                    attributes: attributes)
        return snapshot
    }
    
    func load(frames rawFrames: [RawFrame],
              in trans: AppendingTransaction,
              reservation: borrowing IdentityReservation) throws (RawDesignLoaderError) {
        
        for (i, rawFrame) in rawFrames.enumerated() {
            let frameID = reservation.frames[i]
            var snapshots: [DesignObject] = []
            for rawSnapshotID in rawFrame.snapshots {
                guard let snapshotRes = reservation[rawSnapshotID], snapshotRes.type == .snapshot else {
                    throw .frameError(i, .unknownSnapshotID(rawSnapshotID))
                }
                guard let snapshot = trans.snapshots.snapshot(snapshotRes.id) else {
                    throw .frameError(i, .unknownSnapshotID(rawSnapshotID))
                }
                snapshots.append(snapshot)
            }
            let frame = DesignFrame(design: trans.design, id: frameID, snapshots: snapshots)
            trans.insert(frame: frame)
        }
    }
    struct NamedReference {
        let type: String
        let id: ObjectID
    }
    struct NamedReferenceList {
        let type: String
        let ids: [ObjectID]
    }
    func makeNamedReferences(_ refs: [RawNamedReference],
                             with reservation: borrowing IdentityReservation)
    throws (RawDesignLoaderError) -> [String:NamedReference] {
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
    throws (RawDesignLoaderError) -> [String:NamedReferenceList] {
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


