//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2023.
//

import Foundation
import ArgumentParser

extension PoieticTool {
    struct Metamodel: ParsableCommand {
        // TODO: Add import from CSV with format: id,attr,value
        static var configuration
            = CommandConfiguration(
                abstract: "Show the metamodel"
            )

        @OptionGroup var options: Options
        
        mutating func run() throws {
            let memory = try openMemory(options: options)
            let metamodel = memory.metamodel
            
            print("TYPES AND COMPONENTS\n")

            for type in metamodel.objectTypes {
                print("\(type.name) – \(type.structuralType)")
                if type.components.isEmpty {
                    print("    (no components)")
                }
                else {
                    for req in type.components {
                        print("    \(req.description)")
                    }
                }
            }
            
            print("\nCONSTRAINTS\n")
            
            for constr in metamodel.constraints {
                print("\(constr.name): \(constr.description ?? "(no description)")")
            }
            
            print("")
        }
    }

}
