//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/07/2023.
//

import Foundation

extension ForeignAtom {
    public static func fromJSON(_ string: String) throws -> ForeignAtom {
        let data = Data(string.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(ForeignAtom.self, from: data)
    }
    
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let string = String(data:data, encoding: .utf8)
        return string!
    }
}

extension ForeignValue {
    public static func fromJSON(_ string: String) throws -> ForeignValue {
        let data = Data(string.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(ForeignValue.self, from: data)
    }
    
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let string = String(data:data, encoding: .utf8)
        return string!
    }
}
