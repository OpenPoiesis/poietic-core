//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 27/06/2023.
//

import SystemPackage
import Foundation
import ArgumentParser

//let DefaultDOTStyle = DotStyle(
//    nodes: [
//        DotNodeStyle(predicate: AnyNodePredicate(),
//                     attributes: [
//                        "labelloc": "b",
//                     ]),
//        DotNodeStyle(predicate: LabelPredicate(all: "Flow"),
//                     attributes: [
//                        "shape": "ellipse",
//                        "style": "bold",
//
//                     ]),
//        DotNodeStyle(predicate: LabelPredicate(all: "Stock"),
//                     attributes: [
//                        "style": "bold",
//                        "shape": "box",
//                     ]),
//        DotNodeStyle(predicate: LabelPredicate(all: "Auxiliary"),
//                     attributes: [
//                        "shape": "ellipse",
//                        "style": "dotted",
//                     ]),
//    ],
//    edges: [
//        DotEdgeStyle(predicate: LabelPredicate(all: "flow"),
//                     attributes: [
//                        "shape": "ellipse",
//                        "style": "bold",
//                        "color": "blue",
//                        "dir": "both",
//                     ]),
//        DotEdgeStyle(predicate: LabelPredicate(all: "drains"),
//                     attributes: [
//                        "arrowhead": "none",
//                        "arrowtail": "inv",
//                     ]),
//        DotEdgeStyle(predicate: LabelPredicate(all: "fills"),
//                     attributes: [
//                        "arrowhead": "normal",
//                        "arrowtail": "none",
//                     ]),
//        DotEdgeStyle(predicate: LabelPredicate(all: "parameter"),
//                     attributes: [
//                        "arrowhead": "open",
//                        "color": "red",
//                     ]),
//    ]
//)


extension PoieticTool {
    struct WriteDOT: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "Write a Graphviz DOT file.")

        @OptionGroup var options: Options
        
        @Option(name: [.long, .customShort("n")],
                help: "Name of the graph in the output file")
        var name = "output"

        @Option(name: [.long, .customShort("o")],
                help: "Path to a DOT file where the output will be written.")
        var output = "output.dot"

        @Option(name: [.long, .customShort("l")],
                help: "Node attribute that will be used as node label")
        var labelAttribute = "id"
        
        mutating func run() throws {
            let memory = try openMemory(options: options)
           
            guard let testURL = URL(string: output) else {
                fatalError("Invalid resource reference: \(output)")
            }
            let outputURL: URL

            if testURL.scheme == nil {
                outputURL = URL(fileURLWithPath: output)
            }
            else {
                outputURL = testURL
            }

            let exporter = DotExporter(path: FilePath(outputURL.path),
                                       name: name,
                                       labelAttribute: labelAttribute)

            // TODO: Allow export of a selection
            let graph = memory.currentFrame.graph
            try exporter.export(graph: graph)
        }
    }
}
