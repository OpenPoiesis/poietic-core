//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/02/2023.
//

public protocol FrameBase {
    // TODO: Change this to Sequence<ObjectSnapshot>
    var  snapshots: [ObjectSnapshot] { get }
    func contains(_ id: ObjectID) -> Bool
    func object(_ id: ObjectID) -> ObjectSnapshot?
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
}

/// Configuration Plane combines different versions of objects.///
///
/// - Note: In the original paper analogous concept is called `configuration plane`
///   however the more common usage of the term _"configuration"_ nowadays has a
///   different connotation. Despite _configuration_ being more correct for this
///   concept, we go with _arrangement_.
///
public class StableFrame: FrameBase {
    let id: FrameID
    
    /// Versions of objects in the plane.
    ///
    /// Objects not in the map do not exist in the version plane, but might
    /// exist in the object memory.
    ///
    private(set) internal var _snapshots: [ObjectID:ObjectSnapshot]
    
    init(id: FrameID, snapshots: [ObjectSnapshot]? = nil) {
        self.id = id
        self._snapshots = [:]
        
        if let snapshots {
            for snapshot in snapshots {
                self._snapshots[snapshot.id] = snapshot
            }
        }
    }
    
    public var snapshots: [ObjectSnapshot] {
        return Array(_snapshots.values)
    }
    
    public func contains(_ id: ObjectID) -> Bool {
        return _snapshots[id] != nil
    }
    
    public func object(_ id: ObjectID) -> ObjectSnapshot? {
        return _snapshots[id]
    }
}
