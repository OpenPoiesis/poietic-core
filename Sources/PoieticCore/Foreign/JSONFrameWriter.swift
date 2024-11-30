//
//  JSONFrameWriter.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 22/10/2024.
//

import Foundation

/// Utility class.
///
/// - Note: This is just a prototype of a functionality.
///
public class JSONFrameWriter {
    static public func objectToJSON(_ object: DesignObject) throws -> Data {
        let foreign = JSONForeignObject(object)
        let encoder = JSONEncoder()
        let data = try encoder.encode(foreign)
        return data
    }

    /// Create a frame reader.
    ///
    public init() {
        // Nothing here for now
    }
}
