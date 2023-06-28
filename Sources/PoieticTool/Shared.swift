//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/01/2022.
//

import Foundation
import ArgumentParser
import PoieticCore
import PoieticFlows

let defaultDatabase = "Design.poietic"
let databaseEnvironment = "POIETIC_DESIGN"

/// Get the database URL. The database location can be specified by options,
/// environment variable or as a default name, in respective order.
func databaseURL(options: Options) -> URL {
    let location: String
    let env = ProcessInfo.processInfo.environment
    
    if let path = options.database {
        location = path
    }
    else if let path = env[databaseEnvironment] {
        location = path
    }
    else {
        location = defaultDatabase
    }
    
    if let url = URL(string: location) {
        if url.scheme == nil {
            return URL(fileURLWithPath: location, isDirectory: true)
        }
        else {
            return url
        }
    }
    else {
        fatalError("Malformed database location: \(location)")
    }
}

/// Create a new empty memory.
///
func createMemory(options: Options) -> ObjectMemory {
    return ObjectMemory(metamodel: FlowsMetamodel.self)
}

/// Opens a graph from a package specified in the options.
///
func openMemory(options: Options) throws -> ObjectMemory {
    let memory: ObjectMemory = ObjectMemory(metamodel: FlowsMetamodel.self)
    let dataURL = databaseURL(options: options)

    try memory.restoreAll(from: dataURL)
    
    return memory
}

/// Finalize operations on graph and save the graph to its store.
///
func closeMemory(memory: ObjectMemory, options: Options) throws {
    let dataURL = databaseURL(options: options)

    try memory.saveAll(to: dataURL)
}
