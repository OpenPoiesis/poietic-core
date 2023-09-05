//
//  DescribeCommand.swift
//
//
//  Created by Stefan Urbanek on 29/06/2023.
//

import Foundation
import ArgumentParser
import PoieticCore
import PoieticFlows
enum MyError: Error {
    case boo
}

/// Width of the attribute label column for right-aligned display.
///
let AttributeColumnWidth = 20

extension PoieticTool {
    struct Show: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "Describe an object")
        @OptionGroup var options: Options

        @Flag(name: [.customLong("all"), .customShort("a")],
                help: "Show all present components instead of just components predefined by the object's type.")
        var showAll: Bool = false


        @Argument(help: "ID of an object to be described")
        var reference: String
        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            if memory.isEmpty {
                throw CleanExit.message("The design memory is empty.")
            }

            let frame = memory.currentFrame
            
            guard let object = frame.object(stringReference: reference) else {
                throw ToolError.unknownObject(reference)
            }
            
            var items: [(String?, String?)] = [
                ("Type", "\(object.type.name)"),
                ("Object ID", "\(object.id)"),
                ("Snapshot ID", "\(object.snapshotID)"),
                ("Structure", "\(object.structure.type)"),
            ]
            
            let components: [any Component]
            if showAll {
                components = Array(object.components)
            }
            else {
                let types = object.type.components
                components = types.compactMap { object[$0] }
            }
            
            for component in components {
                let desc = type(of: component).componentDescription

                items.append((nil, nil))
                items.append((desc.label, nil))

                for attr in desc.attributes {
                    let rawValue = object.attribute(forKey: attr.name)
                    let displayValue: String
                    if let rawValue {
                        displayValue = String(describing: rawValue)
                    }
                    else {
                        displayValue = "(no value)"
                    }

                    items.append((attr.name, displayValue))
                }
            }
            
            if items.isEmpty {
                print("Object has no components.")
            }
            else {
                let formattedItems = formatLabelledList(items,
                                                        labelWidth: AttributeColumnWidth)
                
                for item in formattedItems {
                    print(item)
                }
            }

        }
    }
}

