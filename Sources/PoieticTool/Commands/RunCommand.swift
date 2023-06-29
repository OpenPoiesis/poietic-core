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

        
        @Argument
        var outputNames: [String] = []
        
        mutating func run() throws {
            let memory = try openMemory(options: options)

            guard let solverType = Solver.registeredSolvers[solverName] else {
                throw ToolError.unknownSolver(solverName)
            }
            
            let frame = memory.deriveFrame(original: memory.currentFrame.id)
            let compiler = Compiler(frame: frame)
            
            // TODO: Catch error
            let compiledModel = try compiler.compile()
            
            // Check output node names
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
            
            let solver = solverType.init(compiledModel)
            
            var time: Double = 0.0
            var state: StateVector = solver.initialize()

            let joinedNames = outputNames.joined(separator:",")
            print("step,time,\(joinedNames)")

            printState(state, time: time, step: 0, ids: namedIDs)

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


