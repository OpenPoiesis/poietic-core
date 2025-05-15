//
//  StoreError.swift
//  
//
//  Created by Stefan Urbanek on 08/05/2024.
//

import Foundation

/// An error thrown when saving and restoring a design to/from a persistent
/// store.
///
/// - SeeAlso: ``MakeshiftDesignStore/load(metamodel:)``,
///   ``MakeshiftDesignStore/save(design:)``
///
public enum DesignStoreError: Error, Equatable, CustomStringConvertible {
    
    // Main errors
    case noStoreURL
    case cannotOpenStore(URL)
    case unableToWrite(URL)
    case dataCorrupted
    case unsupportedFormatVersion(String)
    
    case readingError(RawDesignReaderError)
    case loadingError(RawDesignLoaderError)

    public var description: String {
        switch self {
        case .readingError(let error):
            "Reading error: \(error)"
        case .loadingError(let error):
            "Loading error: \(error)"
        case .noStoreURL:
            "Design store has no URL specified"

        case .dataCorrupted:
            "Store data is corrupted"
        
        // Main errors
        case let .cannotOpenStore(url):
            "Can not open design store: \(url.absoluteString)"
        case let .unableToWrite(url):
            "Can not write store to: \(url.absoluteString)"
        case let .unsupportedFormatVersion(version):
            "Unsupported store format version: \(version)"
        }
    }

}
