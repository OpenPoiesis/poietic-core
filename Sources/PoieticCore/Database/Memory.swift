//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 02/06/2023.
//

/// Error thrown when constraint violations were detected in the graph during
/// `accept()`.
///
public struct ConstraintViolationError: Error {
    let violations: [ConstraintViolation]
}


public class ObjectMemory {
    var identityGenerator: SequentialIDGenerator
   
    let metamodel: Metamodel.Type
    
    var constraints: [Constraint]
    
    var _stableFrames: [FrameID: StableFrame]
    var _mutableFrames: [FrameID: MutableFrame]
    
    // TODO: Decouple the version history from the object memory.
    
    var versionHistory: [FrameID] {
        guard let currentFrameID else {
            return []
        }
        return undoableFrames + [currentFrameID] + redoableFrames
    }
    
    /// ID of the current frame from the history perspective.
    ///
    /// - Note: `currentFrameID` is guaranteed not to be `nil` when there is
    ///   a history.
    var currentFrameID: FrameID?

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

    public internal(set) var undoableFrames: [FrameID] = []
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
    
    public var frames: [StableFrame] {
        return Array(_stableFrames.values)
    }
    
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
    
    
    public func containsFrame(_ id: FrameID) -> Bool {
        return _stableFrames[id] != nil
    }
    
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
        assert(missing.isEmpty,
               "Violated referential integrity of frame ID \(frame.id)")

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
    
    func discard(_ frame: MutableFrame) {
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
