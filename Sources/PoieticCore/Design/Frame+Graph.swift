//
//  Frame+Graph.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 20/05/2025.
//

extension Frame {
    public var nodeKeys: [ObjectID] {
        return self.snapshots.filter { $0.structure.type == .node }.map { $0.objectID }
    }
    
    public var edgeKeys: [ObjectID] {
        return self.snapshots.filter { $0.structure.type == .edge }.map { $0.objectID }
    }

    public var edges: [EdgeObject] {
        return self.snapshots.compactMap {
            EdgeObject($0, in: self)
        }
    }
}

