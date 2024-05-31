//
//  Design.swift
//
//
//  Created by Stefan Urbanek on 02/06/2023.
//

/// Error thrown when constraint violations were detected in the graph during
/// `accept()`.
///
public struct FrameValidationError: Error {
    public let violations: [ConstraintViolation]
    public let typeErrors: [ObjectID: [ObjectTypeError]]
    
    public init(violations: [ConstraintViolation]=[], typeErrors: [ObjectID:[ObjectTypeError]]) {
        self.violations = violations
        self.typeErrors = typeErrors
    }
    
    public var prettyDescriptionsByObject: [ObjectID: [String]] {
        var result: [ObjectID:[String]] = [:]
        
        for violation in violations {
            let message = violation.constraint.abstract ?? "(no constraint description)"
            let desc = "[\(violation.constraint.name)] \(message)"
            for id in violation.objects {
                result[id, default: []].append(desc)
            }
        }
        
        return result
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
/// ``StableFrame`` – immutable version snapshot of a frame, that is guaranteed
/// to be valid and follow all required constraints. The ``MutableFrame``
/// represents a transactional frame, which is "under construction" and does
/// not have yet to maintain integrity. The integrity is enforced once the
/// frame is accepted using ``Design/accept(_:appendHistory:)``.
///
/// ``StableFrame``s can not be mutated, neither any of the object snapshots
/// associated with the frame. They are guaranteed to follow requirements of
/// the metamodel. They are persisted.
///
/// ``MutableFrame``s can be changed, they do not have to follow requirements
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
/// 1. Derive a new frame from an existing one using ``deriveFrame(original:id:)``
///    or create a new empty frame using ``createFrame(id:)`` which produces
///    a new ``MutableFrame``.
/// 2. Add objects to the derived frame using ``MutableFrame/create(_:structure:attributes:components:)``
///    or ``MutableFrame/insert(_:owned:)``.
/// 3. To mutate existing objects in the frame, first derive an new mutable
///    snapshot of the object using ``MutableFrame/mutableObject(_:)`` and
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
/// to a persistent store. All stable frames are stored. Mutable frames are not
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
/// be it a mutable frame or a stable frame. If a frame is removed, all objects
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
    /// Generator of IDs as a sequence of numbers starting from 1.
    ///
    /// Subsequent sequential order continuity is not guaranteed.
    ///
    /// - Note: This is very primitive and naive sequence number generator. If an ID
    ///   is marked as used and the number is higher than current sequence, all
    ///   numbers are just skipped and the next sequence would be the used +1.
    ///
    class IdentityGenerator {
        /// ID as a sequence number.
        var current: ObjectID
        
        /// Creates a sequential ID generator and initializes the sequence to 1.
        public init(_ initialValue: UInt64 = 1) {
            current = initialValue
        }
        
        /// Gets a next sequence id.
        public func next() -> ObjectID {
            let id = current
            current += 1
            return id
        }

        public func markUsed(_ id: ObjectID) {
            self.current = max(self.current, id + 1)
        }
    }

    private var identityGenerator: IdentityGenerator
    
    /// Meta-model that the design conforms to.
    ///
    /// The metamodel is used for validation of the model contained within the
    /// design and for creation of objects.
    ///
    public let metamodel: Metamodel
    
    var _allSnapshots: [SnapshotID: ObjectSnapshot]
    var _stableFrames: [FrameID: StableFrame]
    var _mutableFrames: [FrameID: MutableFrame]
    
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
    public var currentFrame: StableFrame {
        guard let id = currentFrameID else {
            // TODO: What should we do here?
            fatalError("There is no current frame in the history.")
        }
        return _stableFrames[id]!
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
        self.identityGenerator = IdentityGenerator()
        self._stableFrames = [:]
        self._mutableFrames = [:]
        self._allSnapshots = [:]
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
        if let id = required {
            precondition(_allSnapshots[id] == nil,
                         "Trying to allocate an ID \(id) that is already used as a snapshot ID")
            precondition(_stableFrames[id] == nil,
                         "Trying to allocate an ID \(id) that is already used as a stable frame ID")
            precondition(_mutableFrames[id] == nil,
                         "Trying to allocate an ID \(id) that is already used as a mutable frame ID")
            self.identityGenerator.markUsed(id)
            return id
        }
        else {
            return self.identityGenerator.next()
        }
    }
    
    public func snapshot(_ snapshotID: ObjectID) -> ObjectSnapshot? {
        return self._allSnapshots[snapshotID]
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
    public var validatedSnapshots: [ObjectSnapshot] {
        var seen: Set<SnapshotID> = Set()
        var result: [ObjectSnapshot] = []
        
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

    /// Get a sequence of all snapshots
    public var allSnapshots: any Sequence<ObjectSnapshot> {
        return _allSnapshots.values
    }
    
    /// Test whether the design contains a stable frame with given ID.
    ///
    public func containsFrame(_ id: FrameID) -> Bool {
        return _stableFrames[id] != nil
    }
    
    /// Create a new empty mutable frame.
    ///
    /// The frame will be associated with the design.
    ///
    /// To make the frame stable use ``accept(_:appendHistory:)``.
    ///
    /// It is rare that you might want to use this method. See rather
    /// ``deriveFrame(original:id:)``.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``, ``discard(_:)``
    ///
    @discardableResult
    public func createFrame(id: FrameID? = nil) -> MutableFrame {
        let actualID = allocateID(required: id)
        guard _stableFrames[actualID] == nil
                && _mutableFrames[actualID] == nil else {
            fatalError("Design already contains a frame with ID \(actualID)")
        }
        
        let frame = MutableFrame(design: self, id: actualID)
        _mutableFrames[actualID] = frame
        return frame
    }
    
    /// Derive a new frame from an existing frame.
    ///
    /// - Parameters:
    ///     - original: ID of the original frame to be derived. If not provided
    ///       then the most recent frame in the history will be used.
    ///     - id: Proposed ID of the new frame. Must be unique and must not
    ///       already exist in the design. If not provided, a new unique ID
    ///       is generated.
    ///
    /// The newly derived frame will not own any of the objects from the
    /// original frame.
    /// See ``MutableFrame/init(design:id:snapshots:)`` for more information
    /// about how the objects from the original frame are going to be treated.
    ///
    /// - Precondition: The `original` frame must exist in the design.
    /// - Precondition: The design must not contain a frame with `id`.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``, ``discard(_:)``
    ///
    @discardableResult
    public func deriveFrame(original originalID: FrameID? = nil,
                            id: FrameID? = nil) -> MutableFrame {
        let actualID = allocateID(required: id)
        guard _stableFrames[actualID] == nil
                && _mutableFrames[actualID] == nil else {
            fatalError("Can not derive frame: Frame with ID \(actualID) already exists")
        }
        
        let snapshots: [ObjectSnapshot]
        let derived: MutableFrame

        if let originalID {
            guard let originalFrame = _stableFrames[originalID] else {
                fatalError("Can not derive frame: Unknown original stable frame ID \(originalID)")
            }
            snapshots = originalFrame.snapshots
        }
        else {
            if currentFrameID != nil {
                snapshots = currentFrame.snapshots
            }
            else {
                // Empty – we have no current frame
                snapshots = []
            }
        }

        derived = MutableFrame(design: self,
                               id: actualID,
                               snapshots: snapshots)

        _mutableFrames[actualID] = derived
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
        else if _mutableFrames[id] != nil {
            _mutableFrames[id] = nil
        }
        else {
            fatalError("Removing frame failed: unknown frame ID \(id)")
        }
    }
    
    /// Accepts a frame and make it a stable frame.
    ///
    /// Accepting a frame is analogous to a transaction commit in a database.
    ///
    /// Before the frame is accepted it is validated using ``validate(_:)``.
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
    /// - SeeAlso: ``discard()``, ``validate(_:)``
    ///
    @discardableResult
    public func accept(_ frame: MutableFrame, appendHistory: Bool = true) throws -> StableFrame {
        precondition(frame.design === self,
                     "Trying to accept a frame from a different design")
        precondition(frame.state.isMutable,
                     "Trying to accept a frozen frame")
        precondition(_stableFrames[frame.id] == nil,
                     "Trying to accept a frame with ID (\(frame.id)) that has already been accepted")
        precondition(_mutableFrames[frame.id] != nil,
                     "Trying to accept am unknown frame with ID (\(frame.id))")

        try validate(frame)
        
        frame.promote(.validated)
        
        let stableFrame = StableFrame(design: self,
                                      id: frame.id,
                                      snapshots: frame.snapshots)
        _stableFrames[frame.id] = stableFrame
        _mutableFrames[frame.id] = nil
        
        if appendHistory {
            if let currentFrameID {
                undoableFrames.append(currentFrameID)
            }
            redoableFrames.removeAll()
        }
        currentFrameID = frame.id

        return stableFrame
    }
    
    /// Validates a frame for constraints violations and referential integrity.
    ///
    /// This function first check whether the structural referential integrity
    /// is assured – whether the structural details and parent-child hierarchy
    /// have valid object references.
    ///
    /// Secondly the function check the constraints and collect all detected
    /// violations that can be identified.
    ///
    /// If there are any constraint violations found, then the
    /// ``ConstraintViolationError`` is thrown with a list of all detected
    /// violations.
    ///
    /// - Throws: `ConstraintViolationError` when the frame contents violates
    ///   constraints of the design.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``
    ///
    public func validate(_ frame: MutableFrame) throws {
        // Check referential integrity
        // ------------------------------------------------------------
        // NOTE: We no longer can have broken references – see MutableFrame.insert()
        //       However, we check it here for now anyway, just in case.
        //       This check can be removed later, once we are happy and all
        //       is well tested.
        //
        // In other words: It should not longer be possible to have a frame with
        // broken referential integrity.
        //
        let missing: [ObjectID] = frame.brokenReferences()
        
        guard missing.isEmpty else {
            // This is our error, not an user error.
            fatalError("Violated referential integrity of frame ID \(frame.id)")
        }

        // Check types
        // ------------------------------------------------------------
        var typeErrors: [ObjectID: [ObjectTypeError]] = [:]
        
        for object in frame.snapshots {
            for trait in object.type.traits {
                do {
                    try object.validateConformance(to: trait)
                }
                catch let error as ErrorCollection<ObjectTypeError> {
                    typeErrors[object.id, default: []] += error.errors
                }
            }
        }

        // Check constraints
        // ------------------------------------------------------------
        let violations = checkConstraints(frame)
        
        if !violations.isEmpty || !typeErrors.isEmpty {
            throw FrameValidationError(violations: violations,
                                       typeErrors: typeErrors)
        }
    }

    /// Discards the mutable frame that is associated with the design.
    ///
    public func discard(_ frame: MutableFrame) {
        // TODO: Garbage collection
        
        precondition(frame.design === self,
                     "Trying to discard a frame from a different design")
        precondition(frame.state.isMutable,
                     "Trying to discard a frozen frame")
        frame.promote(.validated)
        _mutableFrames[frame.id] = nil
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
    public func checkConstraints(_ frame: Frame) -> [ConstraintViolation] {
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
    
    /// Remove everything from the design.
    ///
    func removeAll() {
        // TODO: [REVIEW] We needed this for archival. Is it still relevant?
        // NOTE: Sync with init(...)
        self.identityGenerator = IdentityGenerator()
        self._allSnapshots.removeAll()
        self._stableFrames.removeAll()
        self._mutableFrames.removeAll()
        self.undoableFrames.removeAll()
        self.redoableFrames.removeAll()
    }
}


public enum ObjectTypeError: Error, Equatable, CustomStringConvertible {
    case missingTraitAttribute(Attribute, String)
    case typeMismatch(Attribute, ValueType)
    
    public var description: String {
        switch self {
        case let .missingTraitAttribute(attribute, trait):
            "Missing attribute '\(attribute.name)' required by trait '\(trait)'"
        case let .typeMismatch(attribute, actualType):
            "Type mismatch of Attribute '\(attribute.name)', \(actualType) is not convertible to \(attribute.type)"
        }
    }
}
