//
//  JSONFrameWriter.swift
//  PoieticCore
//
//  Created by Stefan Urbanek on 22/10/2024.
//

import Foundation

public enum RawDesignWriterError: Error {
    case unableToWrite(URL)
}

/// Utility class.
///
/// - Note: This is just a prototype of a functionality.
///
public class JSONDesignWriter {
    /// Create a frame reader.
    ///
    public init() {
        // Nothing here for now
    }
    
    public func write(_ design: RawDesign, toURL url: URL) throws (RawDesignWriterError) {
        let data = write(design)
        do {
            try data.write(to: url)
        }
        catch {
            throw .unableToWrite(url)
        }
    }

    public func write(_ design: RawDesign) -> Data {
        let encoder = JSONEncoder()
        encoder.userInfo[Variant.CodingTypeKey] = Variant.CodingType.dictionary
        let data: Data

        do {
            data = try encoder.encode(design)
        }
        catch {
            // Not user's fault, it is ours.
            fatalError("Unable to encode raw design. Underlying error: \(error)")
        }
        return data
    }

}
