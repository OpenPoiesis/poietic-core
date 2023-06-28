//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 27/06/2023.
//

import PoieticCore

import ArgumentParser

// The Command
// ------------------------------------------------------------------------

struct PoieticTool: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "poietic",
        abstract: "Poietic design utility.",
        subcommands: [
            CreateDB.self,
//            CreateNode.self,
//            Remove.self,
//            SetAttribute.self,
//            Undo.self,
//            Redo.self,
//            Connect.self,
            List.self,
//            Print.self,
//            Import.self,
//            Export.self,
//            WriteDOT.self,
        ],
        defaultSubcommand: List.self)
}

struct Options: ParsableArguments {
    @Option(name: [.long, .customShort("d")], help: "Path to a poietic design")
    var database: String?
}


PoieticTool.main()
