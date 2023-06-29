//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2023.
//

import ArgumentParser
import PoieticCore
import PoieticFlows

extension PoieticTool {
    struct Info: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "Get information about the design")
        @OptionGroup var options: Options

        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.currentFrame
            let graph = frame.graph
            
            let items: [(String, String)] = [
                ("Current frame", "\(frame.id)"),
                ("Frame objects", "\(frame.snapshots.count)"),
                ("Nodes", "\(graph.nodes.count)"),
                ("Edges", "\(graph.edges.count)"),
                ("Total snapshots", "\(memory.snapshots.count)"),
            ]
            
            let formattedItems = FormatLabelledList(items)
            
            for item in formattedItems {
                print(item)
            }
            
        }
    }
}

