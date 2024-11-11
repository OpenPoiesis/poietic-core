//
//  Design.swift
//
//
//  Created by Stefan Urbanek on 02/06/2023.
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
/// ``ObjectSnapshot/id-swift.property``. The _id_ refers to an object including
/// all its versions – snapshots. Within a frame, the object ID is unique.
///
/// The design distinguishes between two states of a version frame:
/// ``StableFrame`` – immutable version snapshot of a frame, that is guaranteed
/// to be valid and follow all required constraints. The ``TransientFrame``
/// represents a transactional frame, which is "under construction" and does
/// not have yet to maintain integrity. The integrity is enforced once the
/// frame is accepted using ``Design/accept(_:appendHistory:)``.
///
/// ``StableFrame``s can not be mutated, neither any of the object snapshots
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
/// - ToDo: Garbage collection is not yet implemented. This is just a description
///   how it is expected to work.
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
///   we are not appending the frame to a history timeline. Moreover,
///   the mutable frame can be used in an editing session (such as drag/drop
///   session), which is something like a "live transaction".
///
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
    private var objectIDSequence: ObjectID

    var _stableSnapshots: [SnapshotID: StableObject]
    var _stableFrames: [FrameID: StableFrame]

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
    public var currentFrame: StableFrame? {
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
        self._stableSnapshots = [:]
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
    
    /// Create an ID or use a specific ID.
    ///
    /// If an ID is provided, then it is marked as used and accepted. It must
    /// not already exist in the design, otherwise it is a programming error.
    ///
    /// If ID is not provided, then a new ID will be created.
    ///
    /// - Precondition: If ID is specified, it must not be used.
    ///
    public func allocateID(required: ID? = nil) -> ID {
        // FIXME: [REFACTORING] Just use "usedIDs"
        if let id = required {
            precondition(_stableSnapshots[id] == nil,
                         "Trying to allocate an ID \(id) that is already used as a snapshot ID")
            precondition(_stableFrames[id] == nil,
                         "Trying to allocate an ID \(id) that is already used as a stable frame ID")
            precondition(_transientFrames[id] == nil,
                         "Trying to allocate an ID \(id) that is already used as a mutable frame ID")
            
            // Mark the ID as used
            objectIDSequence = max(self.objectIDSequence, id + 1)
            return id
        }
        else {
            let id = objectIDSequence
            objectIDSequence += 1
            return id
        }
    }
    
    public func snapshot(_ snapshotID: ObjectID) -> StableObject? {
        return self._stableSnapshots[snapshotID]
    }

    // MARK: Frames
    
    /// List of all stable frames in the design.
    ///
    public var frames: [StableFrame] {
        return Array(_stableFrames.values)
    }
    
    /// Get a stable frame with given ID.
    ///
    /// - Returns: A frame ID if the design contains a stable frame with given
    ///   ID or `nil` when there is no such stable frame.
    ///
    public func frame(_ id: FrameID) -> StableFrame? {
        return _stableFrames[id]
    }
    
    /// Get a sequence of all snapshots in the design from stable frames,
    /// regardless of their frame presence.
    ///
    /// The order of the returned snapshots is arbitrary.
    ///
    public var validatedSnapshots: [StableObject] {
        var seen: Set<SnapshotID> = Set()
        var result: [StableObject] = []
        
        for frame in self._stableFrames.values {
            for snapshot in frame.snapshots {
                if seen.contains(snapshot.snapshotID) {
                    continue
                }
                seen.insert(snapshot.snapshotID)
                result.append(snapshot)
            }
        }
        
        return result
    }

    /// Get a sequence of all stable snapshots in all frames.
    ///
    public var allSnapshots: any Sequence<StableObject> {
        return _stableSnapshots.values
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
    public func createFrame(deriving original: StableFrame? = nil,
                            id: FrameID? = nil) -> TransientFrame {
        let actualID = allocateID(required: id)
        
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
        if _stableFrames[id] != nil {
            _stableFrames[id] = nil
        }
        else if _transientFrames[id] != nil {
            _transientFrames[id] = nil
        }
        else {
            preconditionFailure("Unknown frame ID \(id) in \(#function)")
        }
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
    ///     ``TransientFrame/accept()``,
    ///     ``TransientFrame/discard()``
    ///
    /// - Precondition: Frame must belong to the design.
    /// - Precondition: Frame must be in transient state.
    /// - Precondition: Frame with give ID must not be already accepted and must
    ///   exist as a transient frame in the design.
    ///
    @discardableResult
    public func accept(_ frame: TransientFrame, appendHistory: Bool = true) throws (FrameConstraintError) -> StableFrame {
        precondition(frame.design === self)
        precondition(frame.state == .transient)
        precondition(_stableFrames[frame.id] == nil,
                     "Frame \(frame.id) already accepted")
        precondition(_transientFrames[frame.id] != nil,
                     "Trying to accept unknown transient frame \(frame.id)")
        
        let checker = ConstraintChecker(metamodel)
        
        try checker.check(frame)

        let snapshots: [StableObject]
        
        do {
            snapshots = try frame.accept()
        }
        catch {
            throw FrameConstraintError(violations: [],
                                       objectErrors: [:],
                                       brokenReferences: frame.brokenReferences())
        }
        
        let stableFrame = StableFrame(design: self,
                                      id: frame.id,
                                      snapshots: snapshots)
        _stableFrames[frame.id] = stableFrame
        _transientFrames[frame.id] = nil
        
        if appendHistory {
            if let currentFrameID {
                undoableFrames.append(currentFrameID)
            }
            redoableFrames.removeAll()
        }
        currentFrameID = frame.id

        return stableFrame
    }
    
    /// Discards the mutable frame that is associated with the design.
    ///
    public func discard(_ frame: TransientFrame) {
        precondition(frame.design === self)
        precondition(frame.state == .transient)

        frame.discard()

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
    /// of undoable history, otherwise it is a programming error.
    ///
    /// - SeeAlso: ``redo(to:)``, ``canUndo``, ``canRedo``
    ///
    public func undo(to frameID: FrameID) {
        guard let index = undoableFrames.firstIndex(of: frameID) else {
            fatalError("Trying to undo to frame \(frameID), which does not exist in the history")
        }

        var suffix = undoableFrames.suffix(from: index)

        let newCurrentFrameID = suffix.removeFirst()

        undoableFrames = Array(undoableFrames.prefix(upTo: index))
        redoableFrames = suffix + [currentFrameID!] + redoableFrames

        currentFrameID = newCurrentFrameID
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
    /// - SeeAlso: ``undo(to:)``, ``canUndo``, ``canRedo``
    ///
    public func redo(to frameID: FrameID) {
        guard let index = redoableFrames.firstIndex(of: frameID) else {
            fatalError("Trying to redo to frame \(frameID), which does not exist in the history")
        }
        var prefix = redoableFrames.prefix(through: index)

        let newCurrentFrameID = prefix.removeLast()
        undoableFrames = undoableFrames + [currentFrameID!] + prefix
        let after = redoableFrames.index(after: index)
        redoableFrames = Array(redoableFrames.suffix(from: after))
        currentFrameID = newCurrentFrameID
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
