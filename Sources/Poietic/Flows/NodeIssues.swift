//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 05/01/2023.
//

public enum NodeIssue: Equatable, CustomStringConvertible, Error {
    case expressionSyntaxError(SyntaxError)
    case unusedInput(String)
    case unknownParameter(String)
    case duplicateName(String)
    
    public var description: String {
        switch self {
        case .expressionSyntaxError(let error):
            return "Syntax error: \(error)"
        case .unusedInput(let name):
            return "Unused input: '\(name)'"
        case .unknownParameter(let name):
            return "Unknown parameter: '\(name)'"
        case .duplicateName(let name):
            return "Duplicate node name: '\(name)'"
        }
    }
}

