//
//  DesignIssue.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 02/03/2025.
//

/// Protocol for errors that can be converted to a design issue.
public protocol IssueConvertible: Error {
    var issueIdentifier: String { get }
    var message: String { get }
    var hints: [String] { get }
    var details: [String: Variant] { get }
}
public extension IssueConvertible {
    var hints: [String] { [] }
    var details: [String: Variant] { [:] }
}

/// Representation of an issue in the design caused by the user.
///
public struct Issue: Sendable, CustomStringConvertible {
    public enum Severity: Sendable, CustomStringConvertible {
        /// Type of an issue that prevents further processing of the design.
        case error
        /// type of an issue that allows further processing of the design, although the result
        /// quality or correctness is not guaranteed.
        case warning
        /// Type of an issue that should never be surfaced to the user. This is typically caused by
        /// an application's wrongdoing or improper validation.
        case fatal
        
        public var description: String {
            switch self {
            case .error: "error"
            case .warning: "warning"
            case .fatal: "fatal"
            }
        }
    }
    
    /// Identifier of the issue.
    ///
    /// Used to look-up the issue in a documentation or for localisation purposes.
    ///
    public let identifier: String

    /// Severity of the issue.
    ///
    /// Typical issue severity is ``Severity/fatal`` which means that the design can not be used
    /// in a meaningful way, neither it can be processed further.
    ///
    public let severity: Severity

    // TODO: Rename to context

    /// Origin of the issue – in which system or part of the application the issue was created.
    ///
    public let source: String

    /// User-oriented error description. Use ordinary user language here, not
    public let message: String

    /// Collection of hints how to try to correct the issue or where to investigate
    /// further.
    public let hints: [String]

    /// List of objects that might be be related in the cause of the issue.
    public let relatedObjects: [ObjectID]

    /// Details about the issue that applications can present or use.
    ///
    /// Known keys:
    ///
    /// - `attribute`: Name of an attribute that caused the issue.
    /// - `trait`: Name of a trait.
    /// - `formula`: Arithmetic expression. See ``ExpressionSyntaxError``.
    ///
    /// - Note: The meaning of keys and values are not formalised yet.
    public let details: [String:Variant]
    
    /// Create a new design issue.
    ///
    /// - Parameters:
    ///     - identifier: Error code.
    ///     - severity: Indicator noting how processable the design is.
    ///     - system: System that detected the issue.
    ///     - error: Concrete error.
    ///       developer's language.
    ///     - relatedObjects: List of objects that might be be related in the cause of the issue.
    ///     - details: dictionary of details that might be presented by the application to the user.
    ///
    public init(identifier: String,
                severity: Severity = .error,
                source: String,
                message: String,
                hints: [String] = [],
                relatedObjects: [ObjectID] = [],
                details: [String : Variant] = [:])
    {
        self.identifier = identifier
        self.severity = severity
        self.source = source
        self.message = message
        self.hints = hints
        self.relatedObjects = relatedObjects
        self.details = details
    }
    
    public var description: String {
        "\(severity.description.uppercased())[\(source),\(identifier)]: \(message)"
    }
}
