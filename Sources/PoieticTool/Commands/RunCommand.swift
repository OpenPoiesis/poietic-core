//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 17/07/2022.
//

import ArgumentParser
import SystemPackage

import PoieticCore
import PoieticFlows

extension PoieticTool {
    struct Run: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "Run a model")

        @OptionGroup var options: Options

        @Option(name: [.long, .customShort("s")],
                help: "Number of steps to run")
        var steps: Int = 10
        
        @Option(name: [.long, .customShort("t")],
                help: "Time delta")
        var timeDelta: Double = 1.0
        
        @Option(name: [.customLong("solver")],
                help: "Type of the solver to be used for computation")
        var solverName: String = "euler"

        
        @Option(name: [.customLong("observe"), .customShort("o")],
                help: "Values to observe in the output; can be object IDs or object names.")
        var outputNames: [String] = []

        @Option(name: [.customLong("constant"), .customShort("c")],
                       help: "Set (override) a value of a constant node in a form 'attribute=value'")
        var overrideValues: [String] = []
        
        mutating func run() throws {
            let memory = try openMemory(options: options)

            guard let solverType = Solver.registeredSolvers[solverName] else {
                throw ToolError.unknownSolver(solverName)
            }
            
            let frame = memory.deriveFrame(original: memory.currentFrame.id)
            let compiledModel = try compile(frame: frame)
            
            // Collect names of nodes to be observed
            // -------------------------------------------------------------
            let namedNodes = compiledModel.namedNodes
            if outputNames.isEmpty {
                outputNames = Array(namedNodes.keys)
            }
            else {
                for name in outputNames {
                    guard namedNodes[name] != nil else {
                        throw ToolError.unknownObjectName(name)
                    }
                }
            }
            var namedIDs: [String:ObjectID] = [:]
            for (name, node) in namedNodes {
                namedIDs[name] = node.id
            }
            
            // Collect constants to be overridden during initialization.
            // -------------------------------------------------------------
            var overrideConstants: [ObjectID: Double] = [:]
            for item in overrideValues {
                guard let split = parseValueAssignment(item) else {
                    throw ToolError.invalidAttributeAssignment(item)
                }
                let (key, stringValue) = split
                guard let doubleValue = Double(stringValue) else {
                    throw ToolError.typeMismatch("constant override '\(key)'", stringValue, "double")
                }
                guard let object = compiledModel.node(named: key) else {
                    throw ToolError.unknownObjectName(key)
                }
                overrideConstants[object.id] = doubleValue
            }
            
            // Create and initialize the solver
            // -------------------------------------------------------------
            let solver = solverType.init(compiledModel)
            
            var time: Double = 0.0
            var state: StateVector = solver.initialize(override: overrideConstants)

            let joinedNames = outputNames.joined(separator:",")
            print("step,time,\(joinedNames)")

            printState(state, time: time, step: 0, ids: namedIDs)

            // Run the simulation
            // -------------------------------------------------------------
            for step in (1...steps) {
                time += timeDelta
                state = try solver.compute(at: time,
                                           with: state,
                                           timeDelta: timeDelta)
                printState(state, time: time, step: step, ids: namedIDs)
            }
        }
        
        func printState(_ state: StateVector, time: Double, step: Int, ids: [String:ObjectID]) {
            var values: [Double] = []
            
            for name in outputNames {
                let value = state[ids[name]!]!
                values.append(value)
            }
            
            let joined = values.map { String($0) }.joined(separator:",")
            print("\(step),\(time),\(joined)")
        }
    }
}

/// Compile the frame and return compiled model, if the frame is valid.
///
/// If there are any compilation errors, they are formatted and printed out.
/// The node names are included for nodes that have a name for user's
/// convenience.
///
/// - Throws: ``ToolError.compilationError`` if there are compilation errors.
///
func compile(frame: MutableFrame) throws -> CompiledModel {
    let compiler = Compiler(frame: frame)
    let compiledModel: CompiledModel
    
    do {
        compiledModel = try compiler.compile()
    }
    catch let error as DomainError {
        for (id, issues) in error.issues {
            for issue in issues {
                let object = frame.object(id)!
                let label: String
                if let name = object.name {
                    label = "\(id)(\(name))"
                }
                else {
                    label = "\(id)"
                }

                print("ERROR: node \(label): \(issue)")
            }
        }
        throw ToolError.compilationError
    }
    
    return compiledModel
}
