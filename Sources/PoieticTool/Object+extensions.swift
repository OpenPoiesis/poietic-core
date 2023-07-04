//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/07/2023.
//

import PoieticCore

extension ObjectSnapshot {
    /// Get object name if it has a "name" attribute (any component)
    ///
    public var name: String? {
        guard let name = self.attribute(forKey: "name") else {
            return nil
        }
        return try? name.stringValue()
    }
}
