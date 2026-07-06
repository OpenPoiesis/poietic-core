//
//  RuntimeEntity+Debug.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 06/07/2026.
//

extension RuntimeEntity {
    /// Get a list of component type names associated with given entity.
    public func debugComponentNames() -> [String] {
        let components = self.world._debugComponents(for: self.runtimeID)
        let names = components.map { String(describing: type(of: $0)) }
        return names
    }
}

