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

        enum OutputFormat: String, CaseIterable, ExpressibleByArgument{
            case simple = "simple"
            case dir = "dir"
            case json = "json"
            var defaultValueDescription: String { "simple" }
            
            static var allValueStrings: [String] {
                OutputFormat.allCases.map { "\($0)" }
            }
        }
        @Option(name: [.long, .customShort("f")], help: "Output format")
        var outputFormat: OutputFormat = .simple

        // TODO: Deprecate
        @Option(name: [.customLong("observe"), .customShort("o")],
                help: "Values to observe in the output; can be object IDs or object names.")
        var outputNames: [String] = []

        // TODO: Deprecate
        @Option(name: [.customLong("constant"), .customShort("c")],
                       help: "Set (override) a value of a constant node in a form 'attribute=value'")
        var overrideValues: [String] = []

        /// Path to the output directory.
        /// The generated files are:
        /// out/
        ///     simulation.csv
        ///     chart-NAME.csv
        ///     data-NAME.csv
        ///
        /// output format:
        ///     - simple: full state only, as CSV
        ///     - json: full state with all outputs as structured JSON
        ///     - dir: directory with all outputs as CSVs (no stdout)
        ///
        @Argument(help: "Output path")
        var output: String = "."
        
        mutating func run() throws {
            fatalError("REFACTORING: CONTINUE HERE")
            
            let memory = try openMemory(options: options)
            guard let solverType = Solver.registeredSolvers[solverName] else {
                throw ToolError.unknownSolver(solverName)
            }
            let simulator = Simulator(memory: memory, solverType: solverType)

            let frame = memory.deriveFrame(original: memory.currentFrame.id)
            do {
                try simulator.compile(frame)
            }
            catch let error as DomainError {
                for (id, issues) in error.issues {
                    for issue in issues {
                        let object = frame.object(id)
                        let label: String
                        if let name = object.name {
                            label = "\(id)(\(name))"
                        }
                        else {
                            label = "\(id)"
                        }

                        print("ERROR: node \(label): \(issue)")
                        if let hint = issue.hint {
                            print("HINT: node \(label): \(hint)")
                        }
                    }
                }
                throw ToolError.compilationError
            }

            let compiledModel = simulator.compiledModel!
            
            // Collect names of nodes to be observed
            // -------------------------------------------------------------
            let variables = compiledModel.simulationVariables
            if outputNames.isEmpty {
                outputNames = Array(variables.map {$0.name})
            }
            else {
                for name in outputNames {
                    guard compiledModel.variable(named: name) != nil else {
                        throw ToolError.unknownObjectName(name)
                    }
                }
            }
            // TODO: We do not need this any more
            var variableIndices: [Int] = variables.map { $0.index }
            for variable in variables {
//                namedIDs[variable.name] = variable.id
            }
            
            // FIXME: Remove this! Replace with JSON for controls
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
                guard let variable = compiledModel.variable(named: key) else {
                    throw ToolError.unknownObjectName(key)
                }
                overrideConstants[variable.id] = doubleValue
            }
            
            // Create and initialize the solver
            // -------------------------------------------------------------
            simulator.initializeSimulation()
            
            // Run the simulation
            // -------------------------------------------------------------
            simulator.run(steps)
            
//            try writeCSV(path: nil,
//                         header: outputNames,
//                         ids: namedIDs,
//                         states: simulator.output)
        }
    }
}

func writeCSV(path: String?,
              header: [String],
              variables: [Int],
              states: [SimulationState]) throws {
    assert(header.count == variables.count)
    // TODO: Step and time
    let writer: CSVWriter
    if let path {
        writer = try CSVWriter(path: path)
    }
    else {
        writer = try CSVWriter(.standardOutput)
    }
    try writer.write(row: header)
    for state in states {
        var row: [String] = []
        for index in variables {
            let value = state[index]
            row.append(String(value))
        }
        try writer.write(row: row)
    }
    try writer.close()
    
}
