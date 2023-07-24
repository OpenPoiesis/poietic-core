//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/02/2023.
//

/// Protocol for version frames.
///
/// Fame Base is a protocol for all version frame types: ``MutableFrame`` and
/// ``StableFrame``
///
public protocol FrameBase {
    // TODO: Change this to Sequence<ObjectSnapshot>
    /// Get a list of all snapshots in the frame.
    ///
    var  snapshots: [ObjectSnapshot] { get }

    /// Get a graph view of the frame.
    ///
    var graph: Graph { get }

    /// Check whether the frame contains an object with given ID.
    ///
    /// - Returns: `true` if the frame contains the object, otherwise `false`.
    ///
    func contains(_ id: ObjectID) -> Bool

    /// Return an object with given ID from the frame or `nil` if the frame
    /// does not contain such object.
    ///
    /// - TODO: This should rather return an non-optional and raise an error.
    ///
    func object(_ id: ObjectID) -> ObjectSnapshot?
    
    /// Asserts that the frame satisfies the given constraint. Raises a
    /// `ConstraintViolation` error if the frame objects violate the constraints.
    ///
    /// - Throws: `ConstraintViolation` when the frame violates given constraint.
    ///
    func assert(constraint: Constraint) throws

    func structuralDependants(id: ObjectID) -> [ObjectID]
    func hasReferentialIntegrity() -> Bool
    func referentialIntegrityViolators() -> [ObjectID]
}

extension FrameBase{
    public func structuralDependants(id: ObjectID) -> [ObjectID] {
        let deps = snapshots.filter {
            $0.structuralDependencies.contains(id)
        }.map {
            $0.id
        }
        return deps
    }
    public func hasReferentialIntegrity() -> Bool {
        return referentialIntegrityViolators().isEmpty
    }
    public func referentialIntegrityViolators() -> [ObjectID] {
        let violators = snapshots.flatMap { snapshot in
            snapshot.structuralDependencies.filter { id in
                !self.contains(id)
            }
        }
        return violators
    }
    
    public func assert(constraint: Constraint) throws {
        let violators = constraint.check(self.graph)
        if violators.isEmpty {
            return
        }
        let violation = ConstraintViolation(constraint: constraint,
                                            objects:violators)
        throw violation
    }
}

/// Stable design frame that can not be mutated.
///
/// The stable frame is a collection of object versions that together represent
/// a version snapshot of a design. The frame is immutable.
///
/// To create a derivative frame from a stable frame use
/// ``ObjectMemory/deriveFrame(original:id:)``.
///
/// - SeeAlso:  ``MutableFrame``
///
public class StableFrame: FrameBase {
    /// ID of the frame.
    ///
    /// ID is unique within the object memory.
    ///
    public let id: FrameID
    
    /// Versions of objects in the plane.
    ///
    /// Objects not in the map do not exist in the version plane, but might
    /// exist in the object memory.
    ///
    private(set) internal var _snapshots: [ObjectID:ObjectSnapshot]
    
    
    /// Create a new stable frame with given ID and with list of snapshots.
    ///
    /// - Precondition: Snapshot must not be mutable.
    ///
    init(id: FrameID, snapshots: [ObjectSnapshot]? = nil) {
        precondition(snapshots?.allSatisfy({ !$0.state.isMutable }) ?? true,
                     "Trying to create a stable frame with one or more mutable snapshots")
        
        self.id = id
        self._snapshots = [:]
        
        if let snapshots {
            for snapshot in snapshots {
                self._snapshots[snapshot.id] = snapshot
            }
        }
    }
    
    /// Get a list of snapshots.
    ///
    public var snapshots: [ObjectSnapshot] {
        return Array(_snapshots.values)
    }
    
    /// Returns `true` if the frame contains an object with given object
    /// identity.
    ///
    public func contains(_ id: ObjectID) -> Bool {
        return _snapshots[id] != nil
    }
    
    /// Return an object snapshots with given object ID.
    ///
    public func object(_ id: ObjectID) -> ObjectSnapshot? {
        return _snapshots[id]
    }
    
    /// Get an immutable graph view of the frame.
    ///
    public var graph: Graph {
        return UnboundGraph(frame: self)
    }
    

}
