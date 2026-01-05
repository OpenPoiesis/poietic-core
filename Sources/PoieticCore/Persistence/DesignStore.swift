//
//  DesignStore.swift
//
//
//  Created by Stefan Urbanek on 20/10/2023.
//

// Versions:
// 0.3.1:
//   - Changed metamodel name to lowercase `default`
//   - Order of snapshots is preserved
// 0.4.0:
//   - Changed to use RawDesign

import Foundation

/// A makeshift persistent store.
///
/// Makeshift persistent design store stores the design as a JSON generated
/// by the Swift _Codable_ protocol.
///
/// - Note: The reason we are using the `Codable` protocol is that the Swift
/// Foundation (at this time) does not have a viable reading/writing of raw JSON
/// that is not bound to the Codable protocol. We need raw reading/writing to
/// adapt for potential version changes of the file being read and for
/// better error reporting.
/// 
/// - Note: This is a solution before we get a proper store design.
///
public class DesignStore {
    public let data: Data?
    public let url: URL?

    /// Create a new makeshift store from data containing a JSON structure.
    ///
    public init(data: Data?=nil, url: URL?=nil) {
        self.url = url
        self.data = data
    }

    /// Load and restore a design from the store.
    ///
    /// - Returns: Restored ``Design`` object.
    /// - Throws: ``DesignStoreError``.
    ///
    public func load(metamodel: Metamodel = Metamodel()) throws (DesignStoreError) -> Design {
        let data: Data
        let design: Design

        if let providedData = self.data {
            data = providedData
        }
        else {
            guard let url = self.url else {
                throw DesignStoreError.noStoreURL
            }
            do {
                data = try Data(contentsOf: url)
            }
            catch {
                throw DesignStoreError.cannotOpenStore(url)
            }
        }
        
        do {
            design = try load(currentVersion: data, metamodel: metamodel)
        }
        catch .unsupportedFormatVersion(let versionString) {
            if let version = SemanticVersion(versionString) {
                switch version {
                default:
                    throw .unsupportedFormatVersion(versionString)
                }
            }
            else {
                throw .unsupportedFormatVersion(versionString)
            }
        }
        return design
    }
    
    public func load(currentVersion data: Data, metamodel: Metamodel = Metamodel()) throws (DesignStoreError) -> Design {
        let reader = JSONDesignReader()
        var rawDesign: RawDesign
        var design: Design
        do {
            rawDesign = try reader.read(data: data)
        }
        catch RawDesignReaderError.unknownFormatVersion(let version) {
            throw .unsupportedFormatVersion(version)
        }
        catch {
            throw .readingError(error)
        }
        
        let loader = DesignLoader(metamodel: metamodel, options: .collectOrphans)
        do {
            design = try loader.load(rawDesign)
        }
        catch {
            throw .loadingError(error)
        }
        return design

    }
    
    /// Save the design to store's URL.
    ///
    /// - Throws: ``DesignStoreError/unableToWrite(_:)``
    public func save(design: Design) throws (DesignStoreError) {
        guard let url = self.url else {
            fatalError("No store URL set to save design to.")
        }

        let extractor = DesignExtractor()
        let rawDesign = extractor.extract(design)
        let encoder = JSONEncoder()
        encoder.userInfo[Variant.CodingTypeKey] = Variant.CodingType.dictionary

        let data: Data

        do {
            data = try encoder.encode(rawDesign)
        }
        catch {
            // Not user's fault, it is ours.
            fatalError("Unable to encode design for persistent store. Underlying error: \(error)")
        }

        do {
            try data.write(to: url)
        }
        catch {
            throw .unableToWrite(url)
        }
    }
}

