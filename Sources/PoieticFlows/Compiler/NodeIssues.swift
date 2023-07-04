//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 05/01/2023.
//

import PoieticCore


/// An aggregate error of multiple issues grouped by a node.
///
/// The ``DomainView`` and ``Compiler`` are trying to gather as many errors as
/// possible to be presented to the user, instead of just failing at the first
/// error found.
///
public struct DomainError: Error {
    /// Dictionary of node issues by node. The key is the node ID and the
    /// value is a list of issues.
    ///
    public internal(set) var issues: [ObjectID:[NodeIssue]]
}


/// An issue detected by the ``DomainView`` or the ``Compiler``.
///
/// The issues are usually grouped in a ``DomainError``, so that as
/// many issues are presented to the user as possible.
///
public enum NodeIssue: Equatable, CustomStringConvertible, Error {
    /// An error caused by a syntax error in the formula (arithmetic expression).
    case expressionSyntaxError(SyntaxError)
    
    /// Parameter connected to a node is not used in the formula.
    case unusedInput(String)
    
    /// Parameter in a formula is not connected from a node.
    case unknownParameter(String)
    
    /// The node has the same name as some other node.
    case duplicateName(String)
    
    /// Get the human-readable description of the issue.
    public var description: String {
        switch self {
        case .expressionSyntaxError(let error):
            return "Syntax error: \(error)"
        case .unusedInput(let name):
            return "Parameter '\(name)' is connected but not used (use it or disconnect it)"
        case .unknownParameter(let name):
            return "Parameter '\(name)' is unknown or not connected (remove it or connect it)"
        case .duplicateName(let name):
            return "Duplicate node name: '\(name)'"
        }
    }
}

