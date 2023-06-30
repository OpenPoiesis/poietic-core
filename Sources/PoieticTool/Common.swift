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
import SystemPackage

enum ToolError: Error, CustomStringConvertible {
    // I/O errors
    case malformedLocation(String)
    case unableToCreateFile(Error)
    
    // Simulation errors
    case unknownObjectName(String)
    case unknownSolver(String)
    case compilationError
    case constraintError
    
    // Query errors
    case malformedObjectReference(String)
    case unknownObject(String)
    case nodeExpected(String)

    // Editing errors
    case noChangesToUndo
    case noChangesToRedo
    
    // Metamodel errors
    case unknownObjectType(String)

    public var description: String {
        switch self {
        case .malformedLocation(let value):
            return "Malformed location: \(value)"
        case .unableToCreateFile(let value):
            return "Unable to create file. Reason: \(value)"

        case .unknownSolver(let value):
            return "Unknown solver '\(value)'"
        case .unknownObjectName(let value):
            return "Unknown object with name '\(value)'"
        case .compilationError:
            return "Design compilation failed"
        case .constraintError:
            return "Model constraint violation"

        case .malformedObjectReference(let value):
            return "Malformed object reference '\(value). Use either object ID or object identifier."
        case .unknownObject(let value):
            return "Unknown object with reference: \(value)"
        case .noChangesToUndo:
            return "No changes to undo"
        case .noChangesToRedo:
            return "No changes to re-do"
        case .unknownObjectType(let value):
            return "Unknown object type '\(value)'"
        case .nodeExpected(let value):
            return "Object is not a node: '\(value)'"
        }
    }
}

let defaultDatabase = "Design.poietic"
let databaseEnvironment = "POIETIC_DESIGN"

/// Get the database URL. The database location can be specified by options,
/// environment variable or as a default name, in respective order.
func databaseURL(options: Options) throws -> URL {
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
        throw ToolError.malformedLocation(location)
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
    let dataURL = try databaseURL(options: options)

    try memory.restoreAll(from: dataURL)
    
    return memory
}

/// Finalize operations on graph and save the graph to its store.
///
func closeMemory(memory: ObjectMemory, options: Options) throws {
    let dataURL = try databaseURL(options: options)

    try memory.saveAll(to: dataURL)
}

/// Try to accept a frame in a memory.
///
/// Tries to accept the frame. If the frame contains constraint violations, then
/// the violations are printed out in a more human-readable format.
///
func acceptFrame(_ frame: MutableFrame, in memory: ObjectMemory) throws {
    // TODO: Print on stderr
    
    do {
        try memory.accept(frame)
    }
    catch let error as ConstraintViolationError {
        for (id, messages) in error.prettyDescriptionsByObject {
            for message in messages {
                print("ERROR: Object \(id): \(message)")
            }
        }
        throw ToolError.constraintError
    }
}
