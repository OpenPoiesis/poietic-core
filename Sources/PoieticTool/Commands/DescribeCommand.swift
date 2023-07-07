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
    struct Describe: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "Describe an object")
        @OptionGroup var options: Options

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
                ("Type", "\(object.type?.name ?? "untyped")"),
                ("Object ID", "\(object.id)"),
                ("Snapshot ID", "\(object.snapshotID)"),
                ("Structure", "\(object.structuralTypeName)"),
            ]
            
            
            // TODO: Assure consistent order of components
            for component in object.components {
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
            
            let formattedItems = formatLabelledList(items,
                                                    labelWidth: AttributeColumnWidth)
            
            for item in formattedItems {
                print(item)
            }

        }
    }
}

