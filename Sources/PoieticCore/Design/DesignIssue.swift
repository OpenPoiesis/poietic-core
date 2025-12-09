//
//  DesignIssue.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 02/03/2025.
//

/// Collection of design issues.
///
public struct DesignIssueCollection: Sendable {
    /// Issues of the design as a whole.
    public var designIssues: [DesignIssue]
    /// Issues specific to particular object.
    public var objectIssues: [ObjectID:[DesignIssue]]
    
    /// Create an empty design issue collection.
    public init() {
        self.designIssues = []
        self.objectIssues = [:]
    }
    
    public var isEmpty: Bool {
        designIssues.isEmpty && objectIssues.isEmpty
    }
    
    public subscript(id: ObjectID) -> [DesignIssue]? {
        return objectIssues[id]
    }
    
    /// Append a design-wide issue.
    ///
    public mutating func append(_ issue: DesignIssue) {
        designIssues.append(issue)
    }
    
    /// Append an issue for a specific object.
    public mutating func append(_ issue: DesignIssue, for id: ObjectID) {
        objectIssues[id, default: []].append(issue)
    }
    public mutating func append(_ issues: [DesignIssue], for id: ObjectID) {
        objectIssues[id, default: []] += issues
    }
}

/// Representation of an issue in the design caused by the user.
///
public struct DesignIssue: Sendable, CustomStringConvertible {
    // TODO: Add priority/weight (to know which display first, or if only one is to be displayed)

    // FIXME: Replace with: system: String or action: String
    public enum Domain: Sendable, CustomStringConvertible {
        /// Issue occurred during validation.
        ///
        /// - SeeAlso: ``Design/accept(_:appendHistory:)``
        ///
        case validation
        
        /// Issue occurred during compilation of the design to some other form.
        case compilation
        
        /// Issue occurred during simulation.
        case simulation
        
        /// Issue occurred when trying to import or export the design through a foreign interface.
        /// For example reading a foreign frame.
        ///
        /// - SeeAlso: ``JSONDesignReader``
        ///
        case foreignInterface
        
        public var description: String {
            switch self {
            case .validation: "validation"
            case .compilation: "compilation"
            case .simulation: "simulation"
            case .foreignInterface: "foreign_interface"
            }
        }
    }
    
    public enum Severity: Sendable, CustomStringConvertible {
        /// Type of an issue that prevents further processing of the design.
        case error
        /// type of an issue that allows further processing of the design, although the result
        /// quality or correctness is not guaranteed.
        case warning
        // TODO: Reconsider existence of the fatal issue – distinguish between errors.
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
    
    /// Issue domain specifies where the issue happened.
    ///
    public let domain: Domain

    /// Severity of the issue.
    ///
    /// Typical issue severity is ``Severity/error`` which means that the design can not be used
    /// in a meaningful way, neither it can be processed further.
    ///
    /// - Note: Value ``Severity/fatal`` serves for debug purposes during development of this
    ///   library and means an internal application error and/or a technical debt.
    ///
    public let severity: Severity
    /// Identifier of the issue kind to be used for investigation, analogous to an error code.
    ///
    public let identifier: String
    
    /// User-oriented message describing the issue.
    public let message: String
    /// Optional hint stating how the issue can be corrected or where to look for further
    /// investigation.
    public let hint: String?
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
    ///     - domain: Domain where the issue occurred.
    ///     - severity: Indicator noting how processable the design is.
    ///     - identifier: Error code.
    ///     - message: User-oriented error description. Use ordinary user language here, not
    ///       developer's language.
    ///     - hint: Information about how the issue can be corrected or where to investigate further.
    ///     - details: dictionary of details that might be presented by the application to the user.
    ///
    public init(domain: Domain,
                severity: Severity = .error,
                identifier: String,
                message: String,
                hint: String? = nil,
                details: [String : Variant] = [:]) {
        self.domain = domain
        self.severity = severity
        self.identifier = identifier
        self.message = message
        self.hint = hint
        self.details = details
    }

    public var description: String {
        return "\(severity)[\(domain),\(identifier)]: \(message)"
    }

}

/// Protocol for errors that can be converted to a design issue.
public protocol DesignIssueConvertible: Error {
    func asDesignIssue() -> DesignIssue
}

// TODO: Rename to ObjectIssue (once we get rid of old object)
public protocol IssueProtocol: Error, Sendable, Equatable {
    var message: String { get }
    var hints: [String] { get }
    
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
    /// Name of a system that caused the issue
    ///
    public let system: String

    public let error: (any IssueProtocol)?

    public var message: String
    public var hints: [String]
    public var relatedObjects: [ObjectID]

    /// Details about the issue that applications can present or use.
    ///
    /// Known keys:
    ///
    /// - `attribute`: Name of an attribute that caused the issue.
    /// - `trait`: Name of a trait.
    ///
    /// - Note: The meaning of keys and values are not formalised yet.
    public let details: [String:Variant]
    
    /// Create a new design issue.
    ///
    /// - Parameters:
    ///     - domain: Domain where the issue occurred.
    ///     - severity: Indicator noting how processable the design is.
    ///     - identifier: Error code.
    ///     - message: User-oriented error description. Use ordinary user language here, not
    ///       developer's language.
    ///     - hint: Information about how the issue can be corrected or where to investigate further.
    ///     - details: dictionary of details that might be presented by the application to the user.
    ///
    public init(identifier: String,
                severity: Severity = .error,
                system: any System,
                error: any IssueProtocol,
                relatedObjects: [ObjectID] = [],
                details: [String : Variant] = [:]) {
        self.identifier = identifier
        self.severity = severity
        self.system = String(describing: type(of: system))
        self.error = error
        self.message = error.message
        self.hints = error.hints
        self.relatedObjects = relatedObjects
        self.details = details
    }
    public init(identifier: String,
                severity: Severity = .error,
                system: String,
                message: String,
                hints: [String] = [],
                relatedObjects: [ObjectID] = [],
                details: [String : Variant] = [:]) {
        self.identifier = identifier
        self.severity = severity
        self.system = system
        self.error = nil
        self.message = message
        self.hints = hints
        self.relatedObjects = relatedObjects
        self.details = details
    }

    public var description: String {
        return "\(severity)[\(system),\(identifier)]: \(message)"
    }

}
