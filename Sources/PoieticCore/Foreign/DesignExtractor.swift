//
//  DesignExtractor.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 09/05/2025.
//


/// Object that exports a design into a raw design representation for foreign interfaces or for
/// unsafe structural surgeries.
///
public class DesignExtractor {
    public init() {
        // Nothing for now
    }

    /// Create a raw design from a design.
    ///
    /// - SeeAlso: ``extract(_:)``, ``RawDesign``, ``RawSnapshot``
    ///
    public func extract(_ design: Design) -> RawDesign {
        var snapshots: [RawSnapshot] = []
        var planes: [RawPlane] = []
        var sysLists: [RawNamedList] = []
        let sysReferences: [RawNamedReference]
        var userReferences: [RawNamedReference] = []

        // 1. Snapshots and planes
        for snapshot in design.objectSnapshots {
            let raw = extract(snapshot)
            snapshots.append(raw)
        }
        for plane in design.planes {
            let raw = extract(plane)
            planes.append(raw)
        }
        
        // 2. System named lists and system named references
        // Write only non-empty ones and non-nil ones (can't write nil ref anyway).
        if !design.undoList.isEmpty {
            let undoList: [RawEntityID] = design.undoList.map { .id($0) }
            sysLists.append(RawNamedList("undo", itemType: "plane", ids: undoList))
        }
        if !design.redoList.isEmpty {
            let redoList: [RawEntityID] = design.redoList.map { .id($0) }
            sysLists.append(RawNamedList("redo", itemType: "plane", ids: redoList))
        }
        
        if let id = design.currentPlaneID {
            sysReferences = [
                RawNamedReference("current_plane", type: "plane", id: .id(id))
            ]
        }
        else {
            sysReferences = []
        }

        // 3. User references
        // Write all, including empty ones.
        for (name, plane) in design.namedPlanes {
            let ref = RawNamedReference(name, type: "plane", id: .id(plane.id))
            userReferences.append(ref)
        }
        
        let rawDesign = RawDesign(
            metamodelName: design.metamodel.name,
            metamodelVersion: design.metamodel.version,
            snapshots: snapshots,
            planes: planes,
            userReferences: userReferences,
            systemReferences: sysReferences,
            systemLists: sysLists
        )
        
        return rawDesign
    }
    
    /// Extract basic raw design attributes without any actual content.
    ///
    /// Use this method to manually populate the raw design.
    ///
    public func extractStub(_ design: Design) -> RawDesign {
        let rawDesign = RawDesign(
            metamodelName: design.metamodel.name,
            metamodelVersion: design.metamodel.version,
        )
        
        return rawDesign
    }

    
    /// Create a raw snapshot representation from a design snapshot.
    ///
    /// - SeeAlso: ``extract(_:)``
    ///
    public func extract(_ snapshot: ObjectSnapshot) -> RawSnapshot {
        let rawParent: RawEntityID? = snapshot.parent.map { .id($0) }
        let raw = RawSnapshot(
            typeName: snapshot.type.name,
            snapshotID: .id(snapshot.snapshotID),
            objectID: .id(snapshot.objectID),
            topology: RawTopology(snapshot.structure),
            parent: rawParent,
            attributes: snapshot.attributes
        )
        return raw
    }
    
    /// Create a raw plane from a design plane.
    ///
    public func extract(_ plane: some Plane) -> RawPlane {
        return RawPlane(
            id: .id(plane.id),
            snapshots: plane.snapshots.map { .id($0.snapshotID) }
        )
    }
    
    /// Extract snapshots from a plane while maintaining referential integrity.
    ///
    /// This method is intended primarily for the "copy" part of the Copy&Paste functionality. Can
    /// be used for safely exporting portions of designs.
    ///
    /// The pruning rules:
    ///
    /// - All nodes and unstructured objects are kept.
    /// - Only edges with endpoints within the provided set of snapshots are kept, others
    ///   are not included in the result.
    /// - Only ordered set (topology type) with the owner in the provided set of snapshots are kept.
    /// - Invalid references in the ordered set topology type are removed, but the ordered set is kept.
    /// - Missing parent is set to `nil`.
    /// - Snapshots not present in the plane are ignored.
    ///
    public func extractPruning(objects objectIDs: [ObjectID], plane: some Plane) -> [RawSnapshot] {
        let knownIDs: Set<ObjectID> = Set(objectIDs)
        var result: [RawSnapshot] = []
        
        
        for id in objectIDs {
            guard let snapshot = plane[id] else { continue }
            let raw: RawSnapshot
            
            switch snapshot.structure {
            case .unstructured, .node:
                raw = extract(snapshot)
            case let .edge(origin, target):
                guard knownIDs.contains(origin) && knownIDs.contains(target) else {
                    continue
                }
                raw = extract(snapshot)
            case let .orderedSet(owner, items):
                guard knownIDs.contains(owner) else {
                    continue
                }
                let knownItems = items.filter { knownIDs.contains($0) }
                raw = extract(snapshot)
                raw.topology.references = [.id(owner)] + knownItems.map { .id($0) }
            }
            
            if let parent = snapshot.parent, !knownIDs.contains(parent) {
                raw.parent = nil
            }
            result.append(raw)
        }

        return result
    }
}
