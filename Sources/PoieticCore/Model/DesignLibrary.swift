//
//  DesignLibrary.swift
//
//
//  Created by Stefan Urbanek on 25/03/2024.
//

import Foundation

// #TODO: This is just a sketch of a larger future functionality.
// Currently used only in the server demo, generated by the
// create-library (CreateLibrary) command in the PoieticFlows command-line tool.
//

public struct DesignLibraryItem: Codable, Sendable {
    public let url: URL
    public let name: String
    public let title: String
    
    public init(url: URL, name: String, title: String) {
        self.url = url
        self.name = name
        self.title = title
    }
}

public struct DesignLibraryInfo: Codable, Sendable {
    public let formatVersion: String
    public let items: [DesignLibraryItem]
    
    public init(items: [DesignLibraryItem]) {
        self.formatVersion = "0.0.1"
        self.items = items
    }
}
