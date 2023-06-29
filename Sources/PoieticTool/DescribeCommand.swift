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
            let frame = memory.currentFrame
            
            guard let object = frame.object(stringReference: reference) else {
                throw ToolError.unknownObject(reference)
            }
            
            print("Type".alignRight(AttributeColumnWidth) + ": \(object.type?.name ?? "untyped")")
            print("")
                  
            print("Object ID".alignRight(AttributeColumnWidth) + ": \(object.id)")
            print("Snapshot ID".alignRight(AttributeColumnWidth) + ": \(object.snapshotID)")
            print("Structure".alignRight(AttributeColumnWidth) + ": \(object.structuralTypeName)")
            
            
            // TODO: Assure consistent order of components
            for component in object.components {
                let desc = type(of: component).componentDescription
                
                print("")
                print("".alignRight(AttributeColumnWidth) + "  " + desc.label)
                print("")
                for attr in desc.attributes {
                    let key = "\(desc.name).\(attr.name)"
                    let rawValue = object.attribute(forKey: key)
                    let displayValue: String
                    if let rawValue {
                        displayValue = String(describing: rawValue)
                    }
                    else {
                        displayValue = "(no value)"
                    }
                    let paddedKey = attr.name.alignRight(AttributeColumnWidth)
                    print("\(paddedKey): \(displayValue)")
                }
            }
        }
    }
}

