//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/01/2022.
//

import Foundation
import ArgumentParser
import PoieticCore
import PoieticFlows

// TODO: Merge with PrintCommand, use --format=id
extension PoieticTool {
    struct List: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "List all nodes and edges")
        @OptionGroup var options: Options

        mutating func run() throws {
            let memory = try openMemory(options: options)
            let graph = memory.currentFrame.graph
            
            print("NODES:")
            let nodes = graph.nodes.sorted { left, right in
                left.id < right.id
            }
            for node in nodes {
                print("    \(node.prettyDescription)")
            }

            print("EDGES:")
            let edges = graph.edges.sorted { left, right in
                left.id < right.id
            }
            for edge in edges {
                print("    \(edge.prettyDescription)")
            }
        }
    }
}

