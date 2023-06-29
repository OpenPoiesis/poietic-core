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

        enum ListType: String, CaseIterable, ExpressibleByArgument{
            case all = "all"
            case names = "names"
            var defaultValueDescription: String { "all" }
            
            static var allValueStrings: [String] {
                ListType.allCases.map { "\($0)" }
            }
        }
        
        @Argument(help: "What kind of list to show.")
        var listType: ListType = .all

        mutating func run() throws {
            let memory = try openMemory(options: options)
            
            
            switch listType {
            case .all:
                listAll(memory)
            case .names:
                listNames(memory)
            }
        }
        func listAll(_ memory: ObjectMemory) {
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
        
        func listNames(_ memory: ObjectMemory) {
            let frame = memory.currentFrame
            
            for object in frame.snapshots {
                guard let component: ExpressionComponent = object[ExpressionComponent.self] else {
                    continue
                }
                print(component.name)
            }
        }
    }
}

