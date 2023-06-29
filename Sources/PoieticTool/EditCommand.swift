//
//  InspectCommand.swift
//
//
//  Created by Stefan Urbanek on 29/06/2023.
//

import Foundation
import ArgumentParser
import PoieticCore
import PoieticFlows


/**
 
 Commands:
 
create node TYPE name=asdf expression=asdasdf
 
 SET sharks expression "10 + 20"

 
 */

extension PoieticTool {
    struct Edit: ParsableCommand {
        static var configuration
        = CommandConfiguration(
            abstract: "Edit an object or a selection of objects",
            subcommands: [
                SetAttribute.self,
                Undo.self,
                Redo.self,
            ]
        )
        
        @OptionGroup var options: Options
    }
}

extension PoieticTool {
    struct SetAttribute: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "set",
                abstract: "Set an attribute value"
            )

        @OptionGroup var options: Options

        
        @Argument(help: "ID of an object to be modified")
        var reference: String

        @Argument(help: "Attribute to be set")
        var attributeName: String

        @Argument(help: "New attribute value")
        var value: String

        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.currentFrame
            
            guard let object = frame.object(stringReference: reference) else {
                throw ToolError.unknownObject(reference)
            }

            let newFrame: MutableFrame = memory.deriveFrame(original: frame.id)

            try newFrame.setAttribute(object.id,
                                      value: ForeignValue(value),
                                      forKey: attributeName)
            try memory.accept(newFrame)

            try closeMemory(memory: memory, options: options)
        }
    }

}

extension PoieticTool {
    struct Undo: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                abstract: "Undo last change"
            )

        @OptionGroup var options: Options

        mutating func run() throws {
            let memory = try openMemory(options: options)
            
            if !memory.canUndo {
                throw ToolError.noChangesToUndo
            }
            
            let frameID = memory.undoableFrames.last!
            
            memory.undo(to: frameID)

            try closeMemory(memory: memory, options: options)
        }
    }

}

extension PoieticTool {
    struct Redo: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                abstract: "Redo undone change"
            )

        @OptionGroup var options: Options

        mutating func run() throws {
            let memory = try openMemory(options: options)
            
            if !memory.canRedo {
                throw ToolError.noChangesToRedo
            }
            
            let frameID = memory.redoableFrames.first!
            
            memory.redo(to: frameID)

            try closeMemory(memory: memory, options: options)
        }
    }

}
