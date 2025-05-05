//
//  Design.swift
//
//
//  Created by Stefan Urbanek on 02/06/2023.
//

import Synchronization

// DEVELOPMENT NOTE:
//
// If adding functionality to Design, make sure that the functionality is
// implementable, and preferably implemented in the poietic-design command-line
// tool. We want to maintain parity between what programmers can do and what
// (expert) users can do without access to the development environment.
//

struct IdentityManager: ~Copyable {
    var sequence: UInt64 = 1
    var usedIDs: Set<UInt64> = Set()
    var reservedIDs: Set<UInt64> = Set()
    
    @inlinable
    func isUsed(_ rawID: UInt64) -> Bool {
        return usedIDs.contains(rawID) || reservedIDs.contains(rawID)
    }
    @inlinable
    func isUsed(_ id: ObjectID) -> Bool {
        return isUsed(id.intValue)
    }
    @inlinable
    mutating func create() -> ObjectID {
        var nextID = sequence
        while isUsed(nextID) {
            nextID += 1
        }
        sequence = nextID + 1
        return ObjectID(nextID)
    }
    @inlinable
    mutating func reserve(_ id: ObjectID) -> Bool {
        if isUsed(id.intValue) {
            return false
        }
        else {
            reservedIDs.insert(id.intValue)
            return true
        }
    }
    @inlinable
    @discardableResult
    mutating func use(_ id: ObjectID) -> Bool {
        let rawID = id.intValue
        guard !usedIDs.contains(rawID) else { return false }
        if reservedIDs.contains(rawID) {
            reservedIDs.remove(rawID)
        }
        usedIDs.insert(rawID)
        return true
    }
    mutating func flushReserved() {
        reservedIDs.removeAll()
    }
}

/// Design is a container representing a model, idea or a document with their
/// history of changes.
///
/// Design comprises of objects, heir attributes and their relationships which
/// which comprise an idea from a problem domain described by a ``Metamodel``.
/// The _Metamodel_ defines types of objects, constraints and other properties
/// of the design, which are used to validate design's integrity.
///
/// Different versions of design objects is organised in _frames_. Each frame
/// represents a change or coupled group of changes either as a change in time
/// or as an alternative. When organised as time-related changes, one can think
/// of a frame of it as a "movie frame".
///
/// Each design object has a unique identity within the whole design referred to as
/// ``ObjectSnapshot/id-swift.property``. The _id_ refers to an object including
/// all its versions – snapshots. Within a frame, the object ID is unique.
///
/// The design distinguishes between two states of a version frame:
/// ``DesignFrame`` – immutable version snapshot of a frame, that is guaranteed
/// to be valid and follow all required constraints. The ``TransientFrame``
/// represents a transactional frame, which is "under construction" and does
/// not have yet to maintain integrity. The integrity is enforced once the
/// frame is accepted using ``Design/accept(_:appendHistory:)``.
///
/// ``DesignFrame``s can not be mutated, neither any of the object snapshots
/// associated with the frame. They are guaranteed to follow requirements of
/// the metamodel. They are persisted.
///
/// ``TransientFrame``s can be changed, they do not have to follow requirements
/// of the metamodel. They are _not_ persisted. See _Archiving_ below.
///
/// The concept of frames allows us to have functionality like undo/redo,
/// version branching, different timelines, sub-system specific annotations
/// without disturbing the original frames, etc.
///
///
/// ## Editing (Mutating)
///
/// Objects of the design are always changed in a relationship with all
/// other objects within the same frame. When a single change requires mutating
/// multiple objects, all the object changes are grouped into a single change
/// that results in a new frame.
///
/// To make a change and produce a new frame:
///
/// 1. Derive a new frame from an existing one or create a new frame using
///   ``createFrame(deriving:id:)``.
/// 2. Add objects to the derived frame using ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
///    or ``TransientFrame/insert(_:)``.
/// 3. To mutate existing objects in the frame, first derive an new mutable
///    snapshot of the object using ``TransientFrame/mutate(_:)`` and
///    make changes using the returned new snapshot.
/// 4. Conclude all the changes by accepting the frame ``accept(_:appendHistory:)``.
///
/// Frame can be accepted only if the constraints are satisfied. When the frame
/// violates ant of the constraints the `accept()` method throws a
/// ``ConstraintViolation`` with more details about which objects violated
/// which constraints.
///
/// If mutable frame for some reason is not going to be used further, for
/// example if it contains domain errors, it can be discarded using
/// ``discard(_:)``. Discarded frame and its derived object will be removed from
/// the design.
///
/// ## Named Frames
///
/// Named frames are used to store design-wide, non-versioned content. For example, application
/// state such as current view position. Named frames can not be included in the undo/redo history.
///
///
/// ## Archiving
///
/// The design can be archived (in the future incrementally synchronised)
/// to a persistent store. All stable frames are stored. Transient frames are not
/// included in the archive and therefore not restored after unarchiving.
/// Therefore one can rely on the archive containing only frames that maintain integrity as defined by the
/// metamodel.
///
/// ## Garbage Collection
///
/// The design keeps only those object snapshots which are contained in frames,
/// be it a transient frame or a stable frame. If a frame is removed, all objects
/// that are referred to only by that frame and no other frame, are removed
/// from the design as well.
///
/// - Remark: The concepts of mutable frame, accept and discard are somewhat
///   analogous to a transaction, commit and rollback respectively. However,
///   accepted frames are not immediately put into a single historical
///   timeline and they might organised into different arrangements. "Rollback"
///   would not make sense, since there might be nothing to go back from, if
///   we are not appending the frame to a history timeline.
///
public class Design {
    /// Meta-model that the design conforms to.
    ///
    /// The metamodel is used for validation of the model contained within the
    /// design and for creation of objects.
    ///
    public let metamodel: Metamodel
    
    /// Value used to generate next object ID.
    ///
    /// - Note: This is very primitive and naive sequence number generator. If an ID
    ///   is marked as used and the number is higher than current sequence, all
    ///   numbers are just skipped and the next sequence would be the used +1.
    ///
    /// - SeeAlso: ``allocateID(required:)``
    ///
    private var objectIDSequence: UInt64
    private var reservedIDs: Set<ObjectID> = Set()
    
    var _storage: SnapshotStorage

    // FIXME: Order of frames is not preserved during persistence
    var _stableFrames: [FrameID: DesignFrame]
    var _namedFrames: [String: DesignFrame]
    // FIXME: [WIP] Use just access methods, do not make this public
    public var namedFrames: [String: DesignFrame] { _namedFrames }
    
    var _transientFrames: [FrameID: TransientFrame]
    
    /// Chronological list of frame IDs.
    ///
    public var versionHistory: [FrameID] {
        guard let currentFrameID else {
            return []
        }
        return undoableFrames + [currentFrameID] + redoableFrames
    }
    
    /// ID of the current frame from the history perspective.
    ///
    /// - Note: `currentFrameID` is guaranteed not to be `nil` when there is
    ///   a history.
    public internal(set) var currentFrameID: FrameID?

    /// Get the current stable frame.
    ///
    /// - Note: It is a programming error to get current frame when there is no
    ///         history.
    ///
    public var currentFrame: DesignFrame? {
        if let currentFrameID {
            return _stableFrames[currentFrameID]
        }
        else {
            return nil
        }
    }

    /// List of IDs of frames that can undone.
    ///
    public internal(set) var undoableFrames: [FrameID] = []

    /// List of IDs of undone frames can be re-done.
    ///
    /// When a new frame is appended to the version history, the list
    /// of re-doable frames is emptied.
    ///
    public internal(set) var redoableFrames: [FrameID] = []

    /// Create a new design that conforms to the given metamodel.
    ///
    /// Newly created design will be set-up as follows:
    ///
    /// - The design will create a copy of the list of metamodel constraints
    ///   during the initialisation. The constraints of the design can be
    ///   changed independently from the metamodel.
    /// - A new empty frame will be created and committed as first frame.
    /// - The history will be initialised with the first empty frame.
    ///
    public init(metamodel: Metamodel = Metamodel()) {
        // NOTE: Sync with removeAll()
        self.objectIDSequence = 1
        self._stableFrames = [:]
        self._transientFrames = [:]
        self._storage = SnapshotStorage()
        self._namedFrames = [:]
        self.undoableFrames = []
        self.redoableFrames = []
        self.metamodel = metamodel
    }
   
    /// True if the design does not contain any stable frames. Mutable frames
    /// do not count.
    /// 
    public var isEmpty: Bool {
        return self._stableFrames.isEmpty
    }
   
    // MARK: - Identity
    // TODO: [WIP] Move to front
    let identityManager:Mutex<IdentityManager> = Mutex(IdentityManager())

    public func createID() -> ObjectID {
        return identityManager.withLock {
            $0.create()
        }
    }
    // TODO: [WIP] Rename this to allocateID, rename allocateID to createID without argument
    public func reserveID(_ id: ObjectID) -> Bool {
        return identityManager.withLock {
            return $0.reserve(id)
        }
    }
    public func useID(_ id: ObjectID) -> Bool {
        return identityManager.withLock {
            return $0.use(id)
        }
    }

    /// Returns `true` if the design contains an entity with given ID.
    ///
    /// Checked IDs are: object snapshot ID, stable frame ID, transient frame ID.
    ///
    public func isUsed(_ id: ObjectID) -> Bool {
        return identityManager.withLock {
            return $0.isUsed(id)
        }
    }
    
    /// Get a sequence of all stable snapshots in all stable frames.
    ///
    public var snapshots: some Collection<DesignObject> {
        return _storage.snapshots
    }

    /// Get a snapshot by snapshot ID.
    ///
    // TODO: Used only in tests
    public func snapshot(_ snapshotID: ObjectID) -> DesignObject? {
        return _storage.snapshot(snapshotID)
    }


    public func contains(snapshot snapshotID: ObjectID ) -> Bool {
        return _storage.contains(snapshotID)
    }
    
    // MARK: Frames
    
    /// List of all stable frames in the design.
    ///
    public var frames: [DesignFrame] {
        return Array(_stableFrames.values)
    }
    
    /// Get a stable frame with given ID.
    ///
    /// - Returns: A frame ID if the design contains a stable frame with given
    ///   ID or `nil` when there is no such stable frame.
    ///
    public func frame(_ id: FrameID) -> DesignFrame? {
        return _stableFrames[id]
    }
    
    /// Get a frame from the list of named frames.
    ///
    /// See the discussion in the ``Design`` about named frames.
    ///
    /// - SeeAlso: ``accept(_:replacingName:)``
    ///
    public func frame(name: String) -> DesignFrame? {
        return _namedFrames[name]
    }

    
    /// Test whether the design contains a stable frame with given ID.
    ///
    public func containsFrame(_ id: FrameID) -> Bool {
        return _stableFrames[id] != nil
    }
    
    
    /// Create a new frame or derive a frame from an existing frame.
    ///
    /// - Parameters:
    ///     - original: A stable frame to derive new frame from. If not provided,
    ///       a new frame will be created.
    ///     - id: Proposed ID of the new frame. Must be unique and must not
    ///       already exist in the design. If not provided, a new unique ID
    ///       is generated.
    ///
    /// The newly derived frame will not own any of the objects from the
    /// original frame.
    /// See ``TransientFrame/init(design:id:snapshots:)`` for more information
    /// about how the objects from the original frame are going to be treated.
    ///
    /// - Precondition: The `original` frame must exist in the design.
    /// - Precondition: The design must not contain a frame with `id`.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``, ``discard(_:)``
    ///
    @discardableResult
    public func createFrame(deriving original: DesignFrame? = nil,
                            id: FrameID? = nil) -> TransientFrame {
        let actualID: ObjectID
        if let id {
            precondition(!useID(id), "ID already used (\(id)")
            actualID = id
        }
        else {
            actualID = createID()
        }
        
        let derived: TransientFrame

        if let original {
            precondition(original.design === self, "Trying to clone a frame from different design")
            
            derived = TransientFrame(design: self,
                                   id: actualID,
                                   snapshots: original.snapshots)
        }
        else {
            derived = TransientFrame(design: self,
                                   id: actualID)
        }


        _transientFrames[actualID] = derived
        return derived
    }
    
    /// Remove a frame from the design.
    ///
    /// - Parameters:
    ///     - id: ID of a stable or a mutable frame owned by the design.
    ///
    /// - Precondition: The frame with given ID must exist in the design.
    ///
    public func removeFrame(_ id: FrameID) {
        if let frame = _stableFrames[id] {
            _stableFrames[id] = nil
            
            for object in frame.snapshots {
                _release(object.snapshotID)
            }
            
            undoableFrames.removeAll { $0 == id }
            redoableFrames.removeAll { $0 == id }
            
            let removeKeys = _namedFrames.compactMap {
                if $0.value.id == id { $0.key }
                else { nil}
            }
            for key in removeKeys {
                _namedFrames[key] = nil
            }
        }
        else if _transientFrames[id] != nil {
            _transientFrames[id] = nil
        }
        else {
            preconditionFailure("Unknown frame ID \(id) in \(#function)")
        }
    }
    
    /// Release a snapshot.
    ///
    /// This method is called when a frame containing a snapshot is removed from the design. If
    /// there are no frames referring to a snapshot, then the snapshot is removed from the design.
    ///
    /// - SeeAlso: ``removeFrame(_:)``
    ///
    public func _release(_ snapshotID: SnapshotID) {
        _storage.release(snapshotID)
    }
    
    /// Insert a new snapshot to the design or retain an existing snapshot.
    ///
    /// This method is called for each snapshot when a frame is accepted to the design.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``
    ///
    func _insertOrRetain(_ snapshot: DesignObject) {
        _storage.insertOrRetain(snapshot)
    }
    
    /// Insert an unique snapshot to the design.
    ///
    /// The inserted snapshot's reference count will be set to 1 and it is expected to be
    /// owned by a frame.
    ///
    /// - Precondition: The snapshot must not exist in the design.
    func insert(unique snapshot: DesignObject) {
        // TODO: Create a concept of "on-hold"
        // TODO: [WIP] Fix this
    }

    /// Accepts a frame and make it a stable frame.
    ///
    /// Accepting a frame is analogous to a transaction commit in a database.
    ///
    /// Before the frame is accepted it is validated using
    /// ``ConstraintChecker/check(_:)``.
    /// If the frame does not violate any constraints and has referential
    /// integrity, then it is frozen: all owned objects in the frame are
    /// frozen.
    ///
    /// A new `StableFrame` is created with all objects from the original
    /// frame. The new frame is added to the list of stable frames.
    ///
    /// If `appendHistory` is `true` then the frame is also added at the end
    /// of the undo list. If there are any redo-able frames, they are all
    /// removed.
    ///
    /// - Returns: The newly created stable frame.
    /// - Throws: `ConstraintViolationError` when the frame contents violates
    ///   constraints of the design.
    ///
    /// - SeeAlso: ``ConstraintChecker/check(_:)``,
    ///     ``TransientFrame/validateStructure()``
    ///
    /// - Precondition: Frame must belong to the design.
    /// - Precondition: Frame must be in transient state.
    /// - Precondition: Frame with give ID must not be already accepted and must
    ///   exist as a transient frame in the design.
    ///
    @discardableResult
    public func accept(_ frame: TransientFrame, appendHistory: Bool = true) throws (StructuralIntegrityError) -> DesignFrame {
        let stableFrame = try _accept(frame)

        if appendHistory {
            if let currentFrameID {
                undoableFrames.append(currentFrameID)
            }
            for id in redoableFrames {
                removeFrame(id)
            }
            redoableFrames.removeAll()
        }
        currentFrameID = frame.id

        return stableFrame
    }

    /// Accept a frame as a named frame, replacing the previous frame with the same name.
    ///
    /// Example:
    ///
    /// ```swift
    /// let original = design.frame(name: "settings")
    /// let trans = design.createFrame(deriving: original)
    /// let settings: MutableObject
    ///
    /// if let obj = trans.first(type: .DiagramSettings) {
    ///    settings = trans.mutate(obj.id)
    /// }
    /// else {
    ///    settings = trans.create(.DiagramSettings)
    /// }
    ///
    /// settings["view_position"] = Variant(Point(100, 100))
    /// settings["view_zoom"] = Variant(2.0)
    ///
    /// try design.accept(trans, replacingName: "settings")
    /// ```
    ///
    /// - SeeAlso: ``frame(name:)``
    ///
    @discardableResult
    public func accept(_ frame: TransientFrame, replacingName name: String) throws (StructuralIntegrityError) -> DesignFrame {
        let old = _namedFrames[name]
        let stable = try _accept(frame)

        if let old {
            removeFrame(old.id)
        }
        _namedFrames[name] = stable
        return stable
    }

    internal func _accept(_ frame: TransientFrame) throws (StructuralIntegrityError) -> DesignFrame {
        precondition(frame.design === self)
        precondition(frame.state == .transient)
        precondition(_stableFrames[frame.id] == nil,
                     "Frame \(frame.id) already accepted")
        precondition(_transientFrames[frame.id] != nil,
                     "Trying to accept unknown transient frame \(frame.id)")
        
        try frame.validateStructure()
        frame.state = .accepted
        
        let snapshots: [DesignObject] = frame.snapshots
        let stableFrame = DesignFrame(design: self, id: frame.id, snapshots: snapshots)

        _stableFrames[frame.id] = stableFrame
        _transientFrames[frame.id] = nil
        
        for snapshot in snapshots {
            _insertOrRetain(snapshot)
        }

        return stableFrame
    }

    
    @discardableResult
    public func validate(_ frame: DesignFrame, metamodel: Metamodel? = nil) throws (FrameValidationError) -> ValidatedFrame {
        precondition(frame.design === self)
        precondition(_stableFrames[frame.id] != nil)
        
        let validationMetamodel = metamodel ?? self.metamodel
        
        let checker = ConstraintChecker(validationMetamodel)
        try checker.check(frame)

        let validated = ValidatedFrame(frame, metamodel: validationMetamodel)
        
        return validated
    }

    /// Discards the mutable frame that is associated with the design.
    ///
    public func discard(_ frame: TransientFrame) {
        precondition(frame.design === self)
        precondition(frame.state == .transient)

        frame.state = .discarded

        _transientFrames[frame.id] = nil
    }
    
    /// Flag whether the design has any un-doable frames.
    ///
    /// - SeeAlso: ``undo(to:)``, ``redo(to:)``, ``canRedo``
    ///
    public var canUndo: Bool {
        return !undoableFrames.isEmpty
    }

    /// Flag whether the design has any re-doable frames.
    ///
    /// - SeeAlso: ``undo(to:)``, ``redo(to:)``, ``canUndo``
    ///
    public var canRedo: Bool {
        return !redoableFrames.isEmpty
    }

    /// Change the current frame to `frameID` which is one of the previous
    /// frames in the undo history.
    ///
    /// It is up to the caller to verify whether the provided frame ID is part
    /// of undoable history.
    ///
    /// - Returns: `true` if there was anything to undo, `false` if there was nothing to undo.
    /// - Precondition: `frameID` must exist in the undo history.
    /// - SeeAlso: ``redo(to:)``, ``canUndo``, ``canRedo``
    ///
    @discardableResult
    public func undo(to frameID: FrameID? = nil) -> Bool {
        guard !undoableFrames.isEmpty else {
            return false
        }
        
        let actualFrameID = frameID ?? undoableFrames.last!
        guard let index = undoableFrames.firstIndex(of: actualFrameID) else {
            fatalError("Trying to undo to frame \(actualFrameID), which does not exist in the history")
        }

        var suffix = undoableFrames.suffix(from: index)

        let newCurrentFrameID = suffix.removeFirst()

        undoableFrames = Array(undoableFrames.prefix(upTo: index))
        redoableFrames = suffix + [currentFrameID!] + redoableFrames

        currentFrameID = newCurrentFrameID
        return true
    }
    
    /// Change the current frame to `frameID` which is one of the previously
    /// undone frames.
    ///
    /// The redo history is emptied when a new frame is derived from the current
    /// frame.
    ///
    /// It is up to the caller to verify whether the provided frame ID is part
    /// of redoable history, otherwise it is a programming error.
    ///
    /// - Returns: `true` if there was anything to redo, `false` if there was nothing to redo.
    /// - Precondition: `frameID` must exist in the redo history.
    /// - SeeAlso: ``undo(to:)``, ``canUndo``, ``canRedo``
    ///
    @discardableResult
    public func redo(to frameID: FrameID? = nil) -> Bool {
        guard !redoableFrames.isEmpty else {
            return false
        }
        
        let actualFrameID = frameID ?? redoableFrames.first!

        guard let index = redoableFrames.firstIndex(of: actualFrameID) else {
            fatalError("Trying to redo to frame \(actualFrameID), which does not exist in the history")
        }
        var prefix = redoableFrames.prefix(through: index)

        let newCurrentFrameID = prefix.removeLast()
        undoableFrames = undoableFrames + [currentFrameID!] + prefix
        let after = redoableFrames.index(after: index)
        redoableFrames = Array(redoableFrames.suffix(from: after))
        currentFrameID = newCurrentFrameID
        return true
    }
    
    /// Check constraints for the given frame.
    ///
    /// - Returns: List of constraint violations.
    /// 
    public func checkConstraints(_ frame: some Frame) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        for constraint in metamodel.constraints {
            let violators = constraint.check(frame)
            if violators.isEmpty {
                continue
            }
            let violation = ConstraintViolation(constraint: constraint,
                                                objects:violators)
            violations.append(violation)
        }
        return violations
    }
}
