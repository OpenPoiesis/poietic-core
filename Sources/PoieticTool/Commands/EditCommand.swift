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
                NewNode.self,
                RemoveNode.self,
            ]
        )
        
        @OptionGroup var options: Options
    }
}

extension PoieticTool {
    struct SetAttribute: ParsableCommand {
        // TODO: Add import from CSV with format: id,attr,value
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
            print("Property set in \(reference): \(attributeName) = \(value)")
            print("Current frame: \(memory.currentFrame.id)")
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
            print("Did undo")
            print("Current frame: \(memory.currentFrame.id)")
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
            print("Did redo.")
            print("Current frame: \(memory.currentFrame.id)")
        }
    }

}

extension PoieticTool {
    struct NewNode: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                abstract: "Create a new node"
            )

        @OptionGroup var options: Options

        @Argument(help: "Type of the node to be created")
        var typeName: String

        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.deriveFrame()
            let graph = frame.mutableGraph
            
            guard let type = FlowsMetamodel.objectType(name: typeName) else {
                throw ToolError.unknownObjectType(typeName)
            }
            
            let id = graph.createNode(type, components: [])
            
            try memory.accept(frame)
            try closeMemory(memory: memory, options: options)

            print("Created node \(id)")
            print("Current frame: \(memory.currentFrame.id)")
        }
    }

}

extension PoieticTool {
    struct RemoveNode: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                abstract: "Create a new node"
            )

        @OptionGroup var options: Options

        @Argument(help: "ID of an object to be removed")
        var reference: String

        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.deriveFrame()
            let graph = frame.mutableGraph
            
            guard let object = frame.object(stringReference: reference) else {
                throw ToolError.unknownObject(reference)
            }

            graph.remove(node: object.id)
            
            try memory.accept(frame)
            try closeMemory(memory: memory, options: options)

            print("Removed node: \(object.id)")
            print("Current frame: \(memory.currentFrame.id)")
        }
    }

}
