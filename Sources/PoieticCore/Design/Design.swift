//
//  Design.swift
//
//
//  Created by Stefan Urbanek on 02/06/2023.
//

//  DEVELOPMENT NOTE:
//
//  If adding functionality to Design, make sure that the functionality is
//  implementable, and preferably implemented in the poietic-design command-line
//  tool. We want to maintain parity between what programmers can do and what
//  (expert) users can do without access to the development environment.
//

// TODO: [WIP]: Rename DesignObject to StableSnapshot, DesignFrame to StableFrame
//

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
/// ``ObjectSnapshotProtocol/id-swift.property``. The _id_ refers to an object including
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
    
    /// Generator of object IDs.
    ///
    public let identityManager: IdentityManager

    var _snapshots: EntityTable<ObjectSnapshot>
    var _frames: EntityTable<StableFrame>
    var _objects: EntityTable<LogicalObject>
    var _transientFrames: [FrameID: TransientFrame]

    var _namedFrames: [String: StableFrame]
    public var namedFrames: [String: StableFrame] { _namedFrames }
    
    
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
    public var currentFrame: StableFrame? {
        guard let currentFrameID else {
            return nil
        }
        return _frames[currentFrameID]
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
    /// The new design will be empty, it will not have any design frames. Typical next step is to
    /// create and populated first frame:
    ///
    /// ```swift
    /// let design = Design(metamodel: Metamodel.Basic)
    /// let trans = design.createFrame()
    /// let object = trans.create(ObjectType.DesignInfo)
    /// object["title"] = "My Design"
    ///
    /// try design.accept(trans)
    /// ```
    /// - SeeAlso: ``createFrame(deriving:id:)``
    ///
    public init(metamodel: Metamodel = Metamodel()) {
        self._snapshots = EntityTable()
        self._frames = EntityTable()
        self._objects = EntityTable()
        self._transientFrames = [:]
        self._namedFrames = [:]
        self.undoableFrames = []
        self.redoableFrames = []
        self.metamodel = metamodel
        self.identityManager = IdentityManager()
    }
   
    /// True if the design does not contain any stable frames. Mutable frames
    /// do not count.
    /// 
    public var isEmpty: Bool {
        return _snapshots.isEmpty && _frames.isEmpty
    }
   
    /// Get a sequence of all stable snapshots in all stable frames.
    ///
    public var snapshots: some Collection<ObjectSnapshot> {
        return _snapshots
    }

    /// Get a snapshot by snapshot ID.
    ///
    // TODO: Used only in tests
    public func snapshot(_ objectID: ObjectID) -> ObjectSnapshot? {
        return _snapshots[objectID]
    }

    public func contains(snapshot snapshotID: ObjectID) -> Bool {
        return _snapshots.contains(snapshotID)
    }
    
    // TODO: [WIP] Used only in tests
    public func referenceCount(_ snapshotID: ObjectID) -> Int? {
        return _snapshots.referenceCount(snapshotID)
    }
    
    // MARK: Frames
    
    /// List of all stable frames in the design.
    ///
    public var frames: some Collection<StableFrame> {
        return _frames.items
    }
    
    /// Get a stable frame with given ID.
    ///
    /// - Returns: A stable frame, if it is contained in the design and is stable (not transient),
    ///   otherwise `nil`.
    ///
    public func frame(_ id: FrameID) -> StableFrame? {
        return _frames[id]
    }

    /// Test whether the design contains a stable frame with given ID.
    ///
    public func containsFrame(_ id: FrameID) -> Bool {
        return _frames[id] != nil
    }
    
    /// Get a frame from the list of named frames.
    ///
    /// See the discussion in the ``Design`` about named frames.
    ///
    /// - SeeAlso: ``accept(_:replacingName:)``
    ///
    public func frame(name: String) -> StableFrame? {
        return _namedFrames[name]
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
    public func createFrame(deriving original: StableFrame? = nil,
                            id: FrameID? = nil) -> TransientFrame {
        // TODO: [WIP] Throw some identity error here
        let actualID: ObjectID
        if let id {
            let success = identityManager.reserve(id, type: .frame)
            precondition(success, "ID already used (\(id)")
            actualID = id
        }
        else {
            actualID = identityManager.createAndReserve(type: .frame)
        }
        
        let derived: TransientFrame

        if let original {
            precondition(original.design === self, "Trying to clone a frame from different design")
            
            derived = TransientFrame(design: self, id: actualID, snapshots: original.snapshots)
        }
        else {
            derived = TransientFrame(design: self, id: actualID)
        }

        _transientFrames[actualID] = derived
        return derived
    }

    /// Discards the mutable frame that is associated with the design.
    ///
    public func discard(_ frame: TransientFrame) {
        precondition(frame.design === self)
        precondition(frame.state == .transient)
        precondition(_transientFrames[frame.id] != nil)

        identityManager.freeReservation(frame.id)
        identityManager.freeReservations(Array(frame._reservations))
        _transientFrames[frame.id] = nil
        frame.discard()
    }
    
    /// Remove a frame from the design.
    ///
    /// The frame will also be removed from named frames, undoable frame list and redo-able frame
    /// list. If the frame was the current frame, then the current frame will be the last frame in
    /// the undo list, if the list is not empty. Otherwise, the current frame will be nil.
    ///
    /// - Parameters:
    ///     - id: ID of a stable frame owned by the design.
    ///
    /// - Precondition: The frame with given ID must exist in the design.
    ///
    public func removeFrame(_ id: FrameID) {
        guard let frame = _frames[id] else {
            preconditionFailure("Unknown frame ID \(id)")
        }
        // Currently no one can retain a frame.
        assert(_frames.referenceCount(id) == 1)

        undoableFrames.removeAll { $0 == id }
        redoableFrames.removeAll { $0 == id }

        // FIXME: [WIP][TEST] Test current frame removal
        if currentFrameID == id {
            if undoableFrames.isEmpty {
                currentFrameID = nil
            }
            else {
                currentFrameID = undoableFrames.removeLast()
            }
        }

        let removeKeys = _namedFrames.compactMap {
            if $0.value.id == id { $0.key }
            else { nil }
        }
        for key in removeKeys {
            _namedFrames[key] = nil
        }

        for snapshot in frame.snapshots {
            _release(snapshot: snapshot.snapshotID)
        }

        _frames.remove(id)
        identityManager.free(id)
    }
    
    /// Release a snapshot.
    ///
    /// This method is called when a frame containing a snapshot is removed from the design. If
    /// there are no frames referring to a snapshot, then the snapshot is removed from the design.
    ///
    /// - SeeAlso: ``removeFrame(_:)``
    ///
    internal func _release(snapshot id: EntityID) {
        guard let snapshot = _snapshots[id] else {
            preconditionFailure("Unknown snapshot ID \(id)")
        }
        // TODO: [WIP][TEST] Test ID release of snapshot and object
        if _snapshots.release(id) {
            identityManager.free(id)
            if _objects.release(snapshot.objectID) {
                identityManager.free(snapshot.objectID)
            }
        }
    }
    
    /// Insert a new snapshot to the design or retain an existing snapshot.
    ///
    /// This method is called for each snapshot when a frame is accepted to the design.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``
    ///
    func BOO_insertOrRetain(_ snapshot: ObjectSnapshot) {
        _snapshots.insertOrRetain(snapshot)
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
    public func accept(_ frame: TransientFrame, appendHistory: Bool = true) throws (StructuralIntegrityError) -> StableFrame {
        let stableFrame = try validateAndInsert(frame)

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
    public func accept(_ frame: TransientFrame, replacingName name: String) throws (StructuralIntegrityError) -> StableFrame {
        let old = _namedFrames[name]
        let stable = try validateAndInsert(frame)

        if let old {
            removeFrame(old.id)
        }
        _namedFrames[name] = stable
        return stable
    }

    internal func validateAndInsert(_ frame: TransientFrame) throws (StructuralIntegrityError) -> StableFrame {
        precondition(frame.design === self)
        precondition(frame.state == .transient)
        precondition(!_frames.contains(frame.id), "Duplicate frame ID \(frame.id)")
        precondition(_transientFrames[frame.id] != nil, "No transient frame with ID \(frame.id)")
        
        try frame.validateStructure()
        
        let snapshots: [ObjectSnapshot] = frame.snapshots
        let stableFrame = StableFrame(design: self, id: frame.id, snapshots: snapshots)

        _transientFrames[frame.id] = nil

        unsafeInsert(stableFrame)
        identityManager.use(reserved: frame.id)
        identityManager.use(reserved: frame._reservations)
        // FIXME: [WIP][TEST] Used reservations
        // FIXME: [WIP][TEST] Used reservations without removed
        frame.accept()
        return stableFrame
    }

    /// Insert a frame without structural or snapshot reference validation.
    ///
    /// This method is used internally by transactions and by the loader.
    ///
    /// The caller is responsible for:
    ///
    /// 1. Validating the frame for structural integrity. See ``Frame/validateStructure()``.
    /// 2. Marking frame ID as used. See ``IdentityManager/use(reserved:)``.
    /// 3. Marking other related reserved identities (snapshot ID, object ID) as used.
    ///    See ``IdentityManager/use(reserved:)-2c5c0``.
    ///
    /// - Parameters:
    ///   - frame: Frame to be inserted.
    ///
    /// - Precondition: The frame ID must be reserved.
    /// - Precondition: The design must not contain a frame with given ID.
    ///
    public func unsafeInsert(_ frame: StableFrame) {
        precondition(frame.design === self)
        precondition(!_frames.contains(frame.id), "Duplicate frame ID \(frame.id)")
        precondition(_transientFrames[frame.id] == nil)

        for snapshot in frame.snapshots {
            if _objects.contains(snapshot.objectID) {
                _objects.retain(snapshot.objectID)
            }
            else {
                // TODO: [WIP][TEST] Test creation/removal of logical object
                _objects.insert(LogicalObject(id: snapshot.objectID))
            }
            _snapshots.insertOrRetain(snapshot)
        }

        _frames.insert(frame)
    }
    
    @discardableResult
    public func validate(_ frame: StableFrame, metamodel: Metamodel? = nil) throws (FrameValidationError) -> ValidatedFrame {
        precondition(frame.design === self)
        precondition(_frames.contains(frame.id))
        
        let validationMetamodel = metamodel ?? self.metamodel
        
        let checker = ConstraintChecker(validationMetamodel)
        try checker.check(frame)

        let validated = ValidatedFrame(frame, metamodel: validationMetamodel)
        
        return validated
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
