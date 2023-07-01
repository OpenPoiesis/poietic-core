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


extension PoieticTool {
    struct Edit: ParsableCommand {
        static var configuration
        = CommandConfiguration(
            abstract: "Edit an object or a selection of objects",
            subcommands: [
                SetAttribute.self,
                Undo.self,
                Redo.self,
                Add.self,
                NewConnection.self,
                Remove.self,
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

            let mutableObject = newFrame.mutableObject(object.id)
            try mutableObject.setAttribute(value: ForeignValue(value),
                                           forKey: attributeName)

            try acceptFrame(newFrame, in: memory)

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
    struct Add: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "add",
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
            
            guard type.structuralType == .node else {
                throw ToolError.structuralTypeMismatch(StructuralType.node.rawValue,
                                                       type.structuralType.rawValue)
            }

            guard !type.isSystemOwned else {
                throw ToolError.creatingSystemOwnedType(type.name)
            }
            
            let id = graph.createNode(type, components: [])
            
            try acceptFrame(frame, in: memory)
            try closeMemory(memory: memory, options: options)

            print("Created node \(id)")
            print("Current frame: \(memory.currentFrame.id)")
        }
    }

}

extension PoieticTool {
    struct Remove: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                abstract: "Remove an object – a node or a connection"
            )

        @OptionGroup var options: Options

        @Argument(help: "ID of an object to be removed")
        var reference: String

        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.deriveFrame()
            
            guard let object = frame.object(stringReference: reference) else {
                throw ToolError.unknownObject(reference)
            }

            let removed = frame.removeCascading(object.id)
            try acceptFrame(frame, in: memory)
            try closeMemory(memory: memory, options: options)

            print("Removed object: \(object.id)")
            if !removed.isEmpty {
                let list = removed.map { String($0) }.joined(separator: ", ")
                print("Removed cascading: \(list)")
            }
            print("Current frame: \(memory.currentFrame.id)")
        }
    }
}

extension PoieticTool {
    struct NewConnection: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "connect",
                abstract: "Create a new connection (edge) between two nodes"
            )

        @OptionGroup var options: Options

        @Argument(help: "Type of the connection to be created")
        var typeName: String

        @Argument(help: "Reference to the connection's origin node")
        var origin: String

        @Argument(help: "Reference to the connection's target node")
        var target: String

        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let frame = memory.deriveFrame()
            let graph = frame.mutableGraph
            
            guard let type = FlowsMetamodel.objectType(name: typeName) else {
                throw ToolError.unknownObjectType(typeName)
            }
            
            guard type.structuralType == .edge else {
                throw ToolError.structuralTypeMismatch(StructuralType.edge.rawValue,
                                                       type.structuralType.rawValue)
            }
            
            guard !type.isSystemOwned else {
                throw ToolError.creatingSystemOwnedType(type.name)
            }

            guard let originObject = frame.object(stringReference: self.origin) else {
                throw ToolError.unknownObject( self.origin)
            }
            
            guard let origin = originObject as? Node else {
                throw ToolError.nodeExpected(self.origin)

            }
            
            guard let targetObject = frame.object(stringReference: self.target) else {
                throw ToolError.unknownObject(self.target)
            }

            guard let target = targetObject as? Node else {
                throw ToolError.nodeExpected(target)

            }

            let id = graph.createEdge(type,
                                      origin: origin.id,
                                      target: target.id,
                                      components: [])
            
            try acceptFrame(frame, in: memory)
            try closeMemory(memory: memory, options: options)

            print("Created edge \(id)")
            print("Current frame: \(memory.currentFrame.id)")
        }
    }

}
