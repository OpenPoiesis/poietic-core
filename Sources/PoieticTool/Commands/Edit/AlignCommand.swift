//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/07/2023.
//

import ArgumentParser
import PoieticCore
import PoieticFlows

enum Alignment: String, CaseIterable, ExpressibleByArgument{
    // Horizontal
    case left = "left"
    case right = "right"
    case center = "center"

    // Vertical
    case top = "top"
    case bottom = "bottom"
    case middle = "middle"

    var defaultValueDescription: String { "center" }
    
    static var allValueStrings: [String] {
        Alignment.allCases.map { "\($0)" }
    }
}


extension PoieticTool {
    struct Align: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                abstract: "Align objects on canvas"
            )

        @OptionGroup var options: Options

        @Option
        var alignment: Alignment = .center

//        @Option(help: "Spacing between objects")
//        var spacing: Double?

        @Argument(help: "IDs of objects to be aligned")
        var references: [String]
        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.deriveFrame()
            
            var objects: [ObjectSnapshot] = []
            
            for ref in references {
                guard let object = frame.object(stringReference: ref) else {
                    throw ToolError.unknownObject(ref)
                }
                objects.append(object)
            }

            let objs = objects.map {$0.id}
            print("ALIGN: \(objs)")
            
            try acceptFrame(frame, in: memory)
            try closeMemory(memory: memory, options: options)

//            print("Current frame ID: \(memory.currentFrame.id)")
        }
    }
}
