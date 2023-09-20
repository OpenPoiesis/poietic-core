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
        @Option(name: [.customLong("variable"), .customShort("V")],
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
        @Option(name: [.customLong("output"), .customShort("o")], help: "Output path. Default or '-' is standard output.")
        var outputPath: String = "-"
        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            guard let solverType = Solver.registeredSolvers[solverName] else {
                throw ToolError.unknownSolver(solverName)
            }
            let simulator = Simulator(memory: memory, solverType: solverType)

            let frame = memory.deriveFrame(original: memory.currentFrame.id)
            do {
                try simulator.compile(frame)
            }
            catch let error as NodeIssuesError {
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
            let variables = compiledModel.allVariables
            if outputNames.isEmpty {
                outputNames = Array(variables.map {$0.name})
            }
            else {
                let allNames = compiledModel.allVariables.map { $0.name }
                let unknownNames = outputNames.filter {
                    !allNames.contains($0)
                }
                guard unknownNames.isEmpty else {
                    throw ToolError.unknownVariables(unknownNames)
                }
            }
            // TODO: We do not need this any more
            var outputVariables: [SimulationVariable] = []
            for name in outputNames {
                let variable = variables.first { $0.name == name }!
                outputVariables.append(variable)
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
            simulator.initializeSimulation(override: overrideConstants)
            
            // Run the simulation
            // -------------------------------------------------------------
            simulator.run(steps)
            
            try writeCSV(path: outputPath,
                         variables: outputVariables,
                         states: simulator.output)
        }
    }
}

func writeCSV(path: String,
              variables: [SimulationVariable],
              states: [SimulationState]) throws {
    let header: [String] = variables.map { $0.name }

    // TODO: Step
    let writer: CSVWriter
    if path == "-" {
        writer = try CSVWriter(.standardOutput)
    }
    else {
        writer = try CSVWriter(path: path)
    }
    try writer.write(row: header)
    for state in states {
        var row: [String] = []
        for variable in variables {
            let value = state[variable]
            row.append(try value.stringValue())
        }
        try writer.write(row: row)
    }
    try writer.close()
    
}
