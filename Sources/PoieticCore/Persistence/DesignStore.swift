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

// TODO: [IMPORTANT] Remove dictionaries from storage and replace with arrays (we want to preserve order)

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
    // TODO: [WIP] Rename back to makeshift store, just a wrapper for reader/loader/...
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
    /// - Throws: ``PersistentStoreError``.
    ///
    public func load(metamodel: Metamodel = Metamodel()) throws (DesignStoreError) -> Design {
        let data: Data
        let design: Design

        if let providedData = self.data {
            data = providedData
        }
        else {
            guard let url = self.url else {
                throw DesignStoreError.storeMissing
            }
            do {
                data = try Data(contentsOf: url)
            }
            catch {
                throw DesignStoreError.cannotOpenStore(url)
            }
        }
        
        do {
            print("--- TRY to load")
            design = try load(currentVersion: data, metamodel: metamodel)
        }
        catch .unsupportedFormatVersion(let versionString) {
            print("--- CATCH unsupported version: \(versionString)")
            if let version = SemanticVersion(versionString) {
                if version < SemanticVersion(0, 4, 0) {
                    design = try load(makeshiftVersion: data, metamodel: metamodel)
                }
                else {
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
        debugPrint("=== READ START")
        do {
            debugPrint("--- Trying to read current version")
            rawDesign = try reader.read(data: data)
        }
        catch RawDesignReaderError.unknownFormatVersion(let version) {
            debugPrint("<<< Unsupported version: \(version)")
            throw .unsupportedFormatVersion(version)
        }
        catch {
            debugPrint("<<< Reading error: ", error)
            throw .readingError(error)
        }
        debugPrint("=== LOAD START")

        let loader = RawDesignLoader(metamodel: metamodel)
        do {
            design = try loader.load(rawDesign)
        }
        catch {
            throw .loadingError(error)
        }
        return design

    }
    // FIXME: [WIP] remove this (handled in the reader
    public func load(makeshiftVersion data: Data, metamodel: Metamodel = Metamodel()) throws (DesignStoreError) -> Design {
        let decoder = JSONDecoder()
        // decoder.userInfo[Self.FormatVersionKey] = Self.FormatVersion
        decoder.userInfo[Variant.CodingTypeKey] = Variant.CodingType.tuple

        debugPrint(">>> DECODING MAKESHIFT")
        let makeshiftDesign: _MakeshiftPersistentDesign
        do {
            makeshiftDesign = try decoder.decode(_MakeshiftPersistentDesign.self, from: data)
        }
        catch let error as DecodingError {
            debugPrint("!!! ERROR: ", error)
            switch error {
            case .dataCorrupted(_):
                throw .dataCorrupted
            case let .keyNotFound(key, context):
                let path = context.codingPath.map { $0.stringValue }
                throw .missingProperty(key.stringValue, path)
            case let .typeMismatch(_, context):
                let path = context.codingPath.map { $0.stringValue }
                throw .typeMismatch(path)
            case let .valueNotFound(key, context):
                let path = context.codingPath.map { $0.stringValue }
                throw .missingValue(String(describing: key), path)
            @unknown default:
                throw .unhandledError("Unknown decoding error case: \(error)")
            }
        }
        catch {
            throw .unhandledError("Unknown decoding error: \(error)")
        }

        let rawDesign = makeshiftDesign.asRawDesign()
        let loader = RawDesignLoader(metamodel: metamodel)
        let design: Design
        do {
            design = try loader.load(rawDesign)
        }
        catch {
            // FIXME: [WIP] Handle errors here (must throw raw loader error)
            fatalError("Handling errors not implemented")
        }
        return design
    }
    
    /// Save the design to store's URL.
    ///
    /// - Throws: ``PersistentStoreError/unableToWrite(_:)``
    public func save(design: Design) throws (DesignStoreError) {
        guard let url = self.url else {
            fatalError("No store URL set to save design to.")
        }
        print("=== Saving store to: \(url)")

        let exporter = RawDesignExporter()
        let rawDesign = exporter.export(design)
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

