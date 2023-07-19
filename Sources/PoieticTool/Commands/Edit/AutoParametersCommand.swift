//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/07/2023.
//

import ArgumentParser
import PoieticCore
import PoieticFlows

extension PoieticTool {
    struct AutoParameters: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "auto-parameters",
                abstract: "Automatically connect parameter nodes: connect required, disconnect unused"
            )

        @OptionGroup var options: Options
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.deriveFrame()
            let graph = frame.mutableGraph
            let view = DomainView(graph)
            
            let builtinNames: Set<String> = Set(FlowsMetamodel.variables.map {
                $0.name
            })
            let nameMap = try view.namesToObjects()
            var didSomething: Bool = false
            
            
            for target in view.expressionNodes {
                let expression = try target.parsedExpression()!
                let allNodeVars: Set<String> = Set(expression.allVariables)
                let required = Array(allNodeVars.subtracting(builtinNames))
                let params = view.parameters(target.id, required: required)
                
                for (name, status) in params {
                    switch status {
                    case .missing:
                        // Find missing parameter
                        let parameterID = nameMap[name]!
                        let edge = graph.createEdge(FlowsMetamodel.Parameter,
                                                    origin: parameterID,
                                                  target: target.id)
                        print("Connected parameter\(name) (\(parameterID)) to \(target.name!) (\(target.id)), edge: \(edge)")
                        didSomething = true
                    case let .unused(node, edge):
                        graph.remove(edge: edge)
                        print("Disconnected parameter \(name) (\(node)) from \(target.name!) (\(target.id)), edge: \(edge)")
                        didSomething = true
                    case .used:
                        continue
                    }
                }
            }

            if didSomething {
                try acceptFrame(frame, in: memory)
            }
            else {
                print("All parameter connections seem to be ok.")
            }
            try closeMemory(memory: memory, options: options)
            
            print("Current frame: \(memory.currentFrame.id)")
        }
    }

}


