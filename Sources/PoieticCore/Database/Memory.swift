//
//  Memory.swift
//
//
//  Created by Stefan Urbanek on 02/06/2023.
//

// Unsolved problems:
// - What to do when constraints or metamodel changes between memory archival?
// - What to do whith the frames that were OK with previous constraints but
//   are not OK with the new constraints?

/// Error thrown when constraint violations were detected in the graph during
/// `accept()`.
///
public struct ConstraintViolationError: Error {
    public let violations: [ConstraintViolation]
    
    public var prettyDescriptionsByObject: [ObjectID: [String]] {
        var result: [ObjectID:[String]] = [:]
        
        for violation in violations {
            let message = violation.constraint.description ?? "(no constraint description)"
            let desc = "[\(violation.constraint.name)] \(message)"
            for id in violation.objects {
                result[id, default: []].append(desc)
            }
        }
        
        return result
    }
}


/// Object Memory is the main managed storage of the Poietic Design.
///
/// Object Memory contains and manages all objects and their versions as well as
/// structural integrity of the design. The object is represented by its identity
/// and might have multiple version snapshots as ``ObjectSnapshot``.
///
/// ## Identity
///
/// Each object has an identity, and in fact, it is just an identity
/// ``ObjectSnapshot/id-swift.property``.
/// Objects snapshots with the same identity represent different versions of
/// the same object. Each snapshot has a snapshot identity
/// ``ObjectSnapshot/snapshotID``. The snapshot identity is unique in the whole
/// memory.
///
/// ## Frames
///
/// A frame can be thought as a snapshot of the design after a change. Different
/// frames represent different versions of the same design, either in time or
/// as alternatives.
///
/// Think of an object memory as a photo library. The version frame is a picture
/// and the object snapshots are the scene in the picture. The frames might be
/// put in an chronological order to represent the history of design evolution.
/// Or they might be put side-by-side to represent alternate design versions.
///
/// The object memory distinguishes between two states of a version frame:
/// ``StableFrame`` – immutable version snapshot of a frame, that is guaranteed
/// to be valid and follow all required constraints. The ``MutableFrame``
/// represents a transactional frame, which is "under construction" and does
/// not have to maintain integrity.
///
/// ``StableFrames`` can not be mutated, neither any of the object snapshots
/// associated with the frame.
///
/// ``MutableFrames`` are not stored in the archive. See _Archiving_ below.
///
/// The concept of frames allows us to have functionality like undo/redo,
/// version branching, different timelines, sub-system specific annotations
/// without disturbing the original frames, etc.
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
/// 2. Add objects to the derived frame using ``MutableFrame/create(_:components:)``
///    or ``MutableFrame/insertDerived(_:id:)``.
/// 3. To mutate existing objects in the frame, first derive an new mutable
///    snapshot of the object using ``MutableFrame/mutableObject(_:)`` and
///    make changes using the returned new snapshot.
/// 4. Conclude all the changes by accepting the frame ``accept(_:appendHistory:)``.
///
/// Frame can be accepted only if the constraints are satisfied. When the frame
/// violates ant of the constraints the `accept()` method throws a
/// ``ConstraintViolationError`` with more details about which objects violated
/// which constraints.
///
/// If mutable frame for some reason is not going to be used further, for
/// example if it contains domain errors, it can be discarded using
/// ``discard(_:)``. Discarded frame and its derived object will be removed from
/// the memory.
///
/// ## Archiving
///
/// - ToDo: Design of object memory archive is not yet finished.
///
/// Object memory can be archived (in the future incrementally synchronised)
/// to a persistent store. All stable frames are stored. Mutable frames are not
/// included in the archive and therefore not restored after unarchiving.
///
/// Archive contains only frames that maintain integrity as defined by the
/// metamodel.
///
/// ## Garbage Collection
///
/// - ToDo: Garbage collection is not yet implemented. This is just a description
///   how it is expected to work.
///
/// The memory keeps only those object snapshots which are contained in frames,
/// be it a mutable frame or a stable frame. If a frame is removed, all objects
/// that are referred to only by that frame and no other frame, are removed
/// from the memory as well.
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
public class ObjectMemory {
    var identityGenerator: SequentialIDGenerator
   
    /// Meta-model associated with the memory.
    ///
    /// The metamodel is used for validation of the model contained within the
    /// memory and for creation of objects.
    ///
    public let metamodel: Metamodel.Type
    
    /// List of constraints of the object memory.
    ///
    /// When accepting the frame using ``accept(_:appendHistory:)`` the frame
    /// is checked using the constraints provided. Only frames that satisfy
    /// the constraints can be accepted.
    ///
    public internal(set) var constraints: [Constraint]
    
    var _stableFrames: [FrameID: StableFrame]
    var _mutableFrames: [FrameID: MutableFrame]
    
    // TODO: Decouple the version history from the object memory.
    
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

    /// Create a new object memory that conforms to the given metamodel.
    ///
    /// Newly created memory will be set-up as follows:
    ///
    /// - The memory will create a copy of the list of metamodel constraints
    ///   during the initialisation. However, the constraints can be changed
    ///   later.
    /// - A new empty frame will be created and committed as first frame.
    /// - The history will be initialised with the first empty frame.
    ///
    public init(metamodel: Metamodel.Type = EmptyMetamodel.self) {
        self.identityGenerator = SequentialIDGenerator()
        self._stableFrames = [:]
        self._mutableFrames = [:]
        self.undoableFrames = []
        self.redoableFrames = []
        self.metamodel = metamodel
        self.constraints = metamodel.constraints
        
//        let firstFrame = StableFrame(id: identityGenerator.next())
//        versionHistory.append(firstFrame.id)
//        _stableFrames[firstFrame.id] = firstFrame
//        self.currentHistoryIndex = versionHistory.startIndex
    }
   
    /// True if the memory does not contain any stable frames. Mutable frames
    /// do not count.
    /// 
    public var isEmpty: Bool {
        return self._stableFrames.isEmpty
    }
    
    /// Create an ID if needed or use a proposed ID.
    ///
    public func createID(_ proposedID: ID? = nil) -> ID {
        if let id = proposedID {
            self.identityGenerator.markUsed(id)
            return id
        }
        else {
            return self.identityGenerator.next()
        }
    }
    
    /// List of all stable frames in the memory.
    ///
    public var frames: [StableFrame] {
        return Array(_stableFrames.values)
    }
    
    /// Get a stable frame with given ID.
    ///
    /// - Returns: A frame ID if the memory contains a stable frame with given
    ///   ID or `nil` when there is no such stable frame.
    ///
    public func frame(_ id: FrameID) -> StableFrame? {
        return _stableFrames[id]
    }
    
    /// Get a sequence of all snapshots in the object memory from stable frames,
    /// regardless of their frame presence.
    ///
    /// The order of the returned snapshots is arbitrary.
    ///
    public var snapshots: [ObjectSnapshot] {
        // TODO: Change this to an iterator
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
    
    /// Test whether the memory contains a stable frame with given ID.
    ///
    public func containsFrame(_ id: FrameID) -> Bool {
        return _stableFrames[id] != nil
    }
    
    /// Create a new empty mutable frame.
    ///
    /// The frame will be associated with the memory.
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
        let actualID = createID(id)
        guard _stableFrames[actualID] == nil
                && _mutableFrames[actualID] == nil else {
            fatalError("Memory already contains a frame with ID \(actualID)")
        }
        
        let frame = MutableFrame(memory: self, id: actualID)
        _mutableFrames[actualID] = frame
        return frame
    }
    
    /// Derive a new frame from an existing frame.
    ///
    /// - Parameters:
    ///     - original: ID of the original frame to be derived. If not provided
    ///       then the most recent frame in the history will be used.
    ///     - id: Proposed ID of the new frame. Must be unique and must not
    ///       already exist in the memory. If not provided, a new unique ID
    ///       is generated.
    ///
    /// The newly derived frame will not own any of the objects from the
    /// original frame.
    /// See ``MutableFrame/init(memory:id:snapshots:)`` for more information
    /// about how the objects from the original frame are going to be treated.
    ///
    /// - Precondition: The `original` frame must exist in the memory.
    /// - Precondition: The memory must not contain a frame with `id`.
    ///
    /// - SeeAlso: ``accept(_:appendHistory:)``, ``discard(_:)``
    ///
    @discardableResult
    public func deriveFrame(original originalID: FrameID? = nil,
                            id: FrameID? = nil) -> MutableFrame {
        let actualID = createID(id)
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

        derived = MutableFrame(memory: self,
                               id: actualID,
                               snapshots: snapshots)

        _mutableFrames[actualID] = derived
        return derived
    }
    
    /// Remove a frame from the memory.
    ///
    /// - Parameters:
    ///     - id: ID of a stable or a mutable frame owned by the memory.
    ///
    /// - Precondition: The frame with given ID must exist in the memory.
    ///
    public func removeFrame(_ id: FrameID) {
        // TODO: What about discard()?
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
    /// The acceptance of the frame to the memory involves:
    ///
    /// - Check whether the structural referential integrity is assured – whether
    ///   edges refer to nodes that are present in the frame.
    /// - Check the constraints and collect all detected violations that can
    ///   be identified.
    /// - If there are any violations, raise `ConstraintViolationError` with a
    ///   list of all detected violations.
    /// - If the frame does not violate any constraints and has referential
    ///   integrity, then it is frozen: all owned objects in the frame are
    ///   frozen.
    /// - New `StableFrame` is created with all objects from the original
    ///   frame.
    /// - The new frame is added to the list of stable frames.
    /// - If `appendHistory` is `true` then the frame is also added at the end
    ///   of the undo list. If there are any redo-able frames, they are all
    ///   removed.
    ///
    /// - Throws: `ConstraintViolationError` when the frame contents violates
    ///   constraints of the memory.
    ///
    /// - SeeAlso: `discard()`
    ///
    public func accept(_ frame: MutableFrame, appendHistory: Bool = true) throws {
        precondition(frame.memory === self,
                     "Trying to accept a frame from a different memory")
        precondition(frame.state.isMutable,
                     "Trying to accept a frozen frame")
        precondition(_stableFrames[frame.id] == nil,
                     "Trying to accept a frame with ID (\(frame.id)) that has already been accepted")
        precondition(_mutableFrames[frame.id] != nil,
                     "Trying to accept am unknown frame with ID (\(frame.id))")

        // Check referential integrity
        // ------------------------------------------------------------
        var missing: [ObjectID] = []
        
        // TODO: Move this to frame
        for obj in frame.derivedObjects {
            for dep in obj.structuralDependencies {
                if !frame.contains(dep) {
                    missing.append(dep)
                }
            }
        }
        // TODO: Should we make this into an exception? For now it is a programming error.
        guard missing.isEmpty else {
            fatalError("Violated referential integrity of frame ID \(frame.id)")
        }

        // Check constraints
        // ------------------------------------------------------------
        // TODO: What about non-graph constraints – Pure object constraints?
        
        // TODO: We need to get an immutable graph here.
        let graph = frame.mutableGraph
        var violations: [ConstraintViolation] = []
        for constraint in constraints {
            let violators = constraint.check(graph)
            if violators.isEmpty {
                continue
            }
            let violation = ConstraintViolation(constraint: constraint,
                                                objects:violators)
            violations.append(violation)
        }
        
        if !violations.isEmpty {
            throw ConstraintViolationError(violations: violations)
        }

        frame.freeze()
        
        let stableFrame = StableFrame(id: frame.id,
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
        
    }
    
    /// Add a constraint to the memory.
    ///
    /// Before adding the constraint to the memory, all stable frames are
    /// checked whether they violate the new constraint or not. If none
    /// of the frames violates the constraint, then it is added to the
    /// list of constraints.
    ///
    /// - Throws: `ConstraintViolation` for the first frame that violates the new
    /// constraint.
    ///
    func addConstraint(_ constraint: Constraint) throws {
        // TODO: Check all frames and include violating frame ID.
        // TODO: Add tests.
        
        for (_, frame) in self._stableFrames {
            try frame.assert(constraint: constraint)
        }
        constraints.append(constraint)
    }
    /// Remove a constraint from the memory.
    ///
    /// This method just removes the constraint and takes no other action.
    ///
    func removeConstraint(_ constraint: Constraint) {
        constraints.removeAll {
            $0 === constraint
        }
    }
    
    /// Discards the mutable frame that is associated with the memory.
    ///
    public func discard(_ frame: MutableFrame) {
        // TODO: Clean-up all the objects.
        
        precondition(frame.memory === self,
                     "Trying to discard a frame from a different memory")
        precondition(frame.state.isMutable,
                     "Trying to discard a frozen frame")
        frame.freeze()
        _mutableFrames[frame.id] = nil
    }
    
    public var canUndo: Bool {
        return !undoableFrames.isEmpty
    }

    public var canRedo: Bool {
        return !redoableFrames.isEmpty
    }

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
    
    func checkConstraints() {
        fatalError("Check constraints not implemented")
    }
}
