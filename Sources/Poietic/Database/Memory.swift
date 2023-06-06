//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 02/06/2023.
//

import Foundation

class ObjectMemory {
    var identityGenerator: SequentialIDGenerator
   
    var _stableFrames: [FrameID: StableFrame]
    var _mutableFrames: [FrameID: MutableFrame]
    
    // TODO: Decouple the version history from the object memory.
    
    var versionHistory: [FrameID]
    var currentHistoryIndex: Array<FrameID>.Index?
    
    var currentFrameID: FrameID { versionHistory[currentHistoryIndex!] }
    var currentFrame: StableFrame { _stableFrames[currentFrameID]! }

    var undoableFrames: [FrameID] {
        if let index = currentHistoryIndex {
            return Array(versionHistory.prefix(through: index))
        }
        else {
            return []
        }
    }
    var redoableFrames: [FrameID] {
        if let index = currentHistoryIndex {
            let next = versionHistory.index(after:index)
            return Array(versionHistory.suffix(from: next))
        }
        else {
            return []
        }
    }

    // var metamodel:
    
    init() {
        self.identityGenerator = SequentialIDGenerator()
        self._stableFrames = [:]
        self._mutableFrames = [:]
        self.versionHistory = []

        
        let firstFrame = StableFrame(id: identityGenerator.next())
        versionHistory.append(firstFrame.id)
        _stableFrames[firstFrame.id] = firstFrame
        self.currentHistoryIndex = versionHistory.startIndex
    }
        
    /// Create an ID if needed or use a proposed ID.
    ///
    func createID(_ proposedID: ID? = nil) -> ID {
        if let id = proposedID {
            self.identityGenerator.markUsed(id)
            return id
        }
        else {
            return self.identityGenerator.next()
        }
    }
    
    var frames: any Sequence<StableFrame> {
        return _stableFrames.values
    }
    
    func frame(_ id: FrameID) -> StableFrame? {
        return _stableFrames[id]
    }
    
    /// Get a sequence of all snapshots in the object memory from stable frames,
    /// regardless of their frame presence.
    ///
    /// The order of the returned snapshots is arbitrary.
    ///
    var snapshots: [ObjectSnapshot] {
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
    
    
    func containsFrame(_ id: FrameID) -> Bool {
        return _stableFrames[id] != nil
    }
    
    func createFrame(id: FrameID? = nil) -> MutableFrame {
        let actualID = createID(id)
        guard _stableFrames[actualID] == nil
                && _mutableFrames[actualID] == nil else {
            fatalError("Memory already contains a frame with ID \(actualID)")
        }
        
        let frame = MutableFrame(memory: self, id: actualID)
        _mutableFrames[actualID] = frame
        return frame
    }
    
    func deriveFrame(original originalID: FrameID? = nil,
                     id: FrameID? = nil) -> MutableFrame {
        let actualID = createID(id)
        guard _stableFrames[actualID] == nil
                && _mutableFrames[actualID] == nil else {
            fatalError("Can not derive frame: Frame with ID \(actualID) already exists")
        }
        
        let actualOriginalID = originalID ?? currentFrameID
        guard let originalFrame = _stableFrames[actualOriginalID] else {
            fatalError("Can not derive frame: Unknown original stable frame ID \(actualOriginalID)")
        }
        let derived = MutableFrame(memory: self,
                                   id: actualID,
                                   snapshots: originalFrame.snapshots)

        _mutableFrames[actualID] = derived
        return derived
    }
    
    func removeFrame(_ id: FrameID) {
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
    func accept(_ frame: MutableFrame, appendHistory: Bool = true) {
        precondition(frame.memory === self,
                     "Trying to accept a frame from a different memory")
        precondition(frame.state.isMutable,
                     "Trying to accept a frozen frame")
        precondition(_stableFrames[frame.id] == nil,
                     "Trying to accept a frame with ID (\(frame.id)) that has already been accepted")
        precondition(_mutableFrames[frame.id] != nil,
                     "Trying to accept am unknown frame with ID (\(frame.id))")

        var missing: [ObjectID] = []
        
        // TODO: Move this to frame
        for obj in frame.derivedObjects {
            for dep in obj.structuralDependencies {
                if !frame.contains(dep) {
                    missing.append(dep)
                }
            }
        }
        assert(missing.isEmpty,
               "Violated referential integrity of frame ID \(frame.id)")

        frame.freeze()
        let stableFrame = StableFrame(id: frame.id,
                                      snapshots: frame.snapshots)
        _stableFrames[frame.id] = stableFrame
        _mutableFrames[frame.id] = nil
        
        if appendHistory {
            if let index = currentHistoryIndex {
                let pruneIndex = versionHistory.index(after: index)
                if pruneIndex < versionHistory.endIndex {
                    versionHistory.removeSubrange(pruneIndex..<versionHistory.endIndex)
                }
                versionHistory.append(frame.id)
                currentHistoryIndex = versionHistory.index(after: index)
            }
            else {
                versionHistory.append(frame.id)
                currentHistoryIndex = versionHistory.endIndex
            }
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
    
    func undo(to frameID: FrameID) {
        guard let index = versionHistory.firstIndex(of: frameID) else {
            fatalError("Trying to undo to frame \(frameID), which does not exist in the history")
        }
        assert(index < currentHistoryIndex!)
        currentHistoryIndex = index
    }
    func redo(to frameID: FrameID) {
        guard let index = versionHistory.firstIndex(of: frameID) else {
            fatalError("Trying to redo to frame \(frameID), which does not exist in the history")
        }
        assert(index > currentHistoryIndex!)

        currentHistoryIndex = index

    }
    
    func checkConstraints() {
        fatalError("Check constraints not implemented")
    }
}
