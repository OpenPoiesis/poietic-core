//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/07/2023.
//

// Basic, reusable components.
public struct NameComponent: InspectableComponent, CustomStringConvertible {
    
    public static var componentDescription = ComponentDescription(
        name: "Name",
        attributes: [
            AttributeDescription(
                name: "name",
                type: .string,
                abstract: "Node name through which the node is known either in the whole design or a smaller context"),
        ]
    )
    
    /// Name of an object.
    ///
    /// Name is a lose reference to an object. Object name is typically used in a
    /// design by the user, for example in formulas.
    ///
    /// Requirements and rules around object names are model-specific. Some models
    /// might require names to be unique, some might have other ways how to
    /// deal with name duplicity.
    ///
    /// For example in the Stock and Flow model, the name must be unique,
    /// otherwise the model will not compile and therefore can not be used.
    ///
    /// - Note: Regardless of the application, users must be allowed to have
    ///         duplicate names in their models during the design phase.
    ///         An error might be indicated to the user before the compilation,
    ///         if a duplicate name is detected, however the design process
    ///         must not be prevented.
    ///
    public var name: String

    /// Creates a a default expression component.
    ///
    /// The name is set to `unnamed`.
    ///
    public init() {
        self.name = "unnamed"
    }
    
    /// Creates an expression node.
    ///
    public init(name: String) {
        self.name = name
    }
    
    public var description: String {
        return "\(name)"
    }
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "name": return ForeignValue(name)
        default: return nil
        }
    }

    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "name": self.name = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

public enum AudienceLevel: Int, Codable {
    case any = 0
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4

    public init(rawValue: Int) {
        switch rawValue {
        case 0: self = .any
        case 1: self = .beginner
        case 2: self = .intermediate
        case 3: self = .advanced
        case 4: self = .expert
        default:
            if rawValue < 0 {
                self = .any
            }
            else {
                self = .expert
            }
        }
    }
    
    /// Compare two audience levels.
    ///
    /// Level `any` is always greater than anything else.
    ///
    static func < (lhs: AudienceLevel, rhs: AudienceLevel) -> Bool {
        if lhs == .any || rhs == .any {
            return false
        }
        else {
            return lhs.rawValue < rhs.rawValue
        }
    }

}

/// A component that can be associated with any object, including the design,
/// to denote intended audience level of the object.
///
/// For example, the user interface can hide or disable editing of objects that
/// are of a higher audience level.
///
struct AudienceLevelComponent: InspectableComponent {
    public static var componentDescription = ComponentDescription(
        name: "AudienceLevel",
        attributes: [
            AttributeDescription(
                name: "audienceLevel",
                type: .int,
                abstract: "Intended level of expertise of the audience interacting with the object"),
        ]
    )
    var audienceLevel: AudienceLevel

    init() {
        self.audienceLevel = .any
    }
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "audienceLevel": return ForeignValue(audienceLevel.rawValue)
        default: return nil
        }
    }

    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "audienceLevel":
            let level = try value.intValue()
            audienceLevel = AudienceLevel(rawValue: level)
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

/// Documentation component
///
public struct DocumentationComponent: InspectableComponent {
    public static var componentDescription = ComponentDescription(
        name: "Documentation",
        attributes: [
            AttributeDescription(
                name: "abstract",
                type: .string,
                abstract: "Short abstract about the object."),
            AttributeDescription(
                name: "documentation",
                type: .string,
                abstract: "Longer object documentation."),
        ]
    )
    public var abstract: String
    public var documentation: String

    public init() {
        self.abstract = ""
        self.documentation = ""
    }
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "abstract": return ForeignValue(abstract)
        case "documentation": return ForeignValue(documentation)
        default: return nil
        }
    }

    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "abstract": self.abstract = try value.stringValue()
        case "documentation": self.abstract = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

/// Keywords component
///
public struct KeywordsComponent: InspectableComponent {
    public static var componentDescription = ComponentDescription(
        name: "Keywords",
        attributes: [
            AttributeDescription(
                name: "keywords",
                type: .array(.string),
                abstract: "List of keywords"),
        ]
    )
    public var keywords: [String]

    public init() {
        self.keywords = []
    }
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "keywords": return ForeignValue(keywords)
        default: return nil
        }
    }

    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "keywords": self.keywords = try value.stringArray()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

/// Note component
///
public struct NoteComponent: InspectableComponent {
    public static var componentDescription = ComponentDescription(
        name: "Note",
        attributes: [
            AttributeDescription(
                name: "note",
                type: .string,
                abstract: "Note text"),
        ]
    )
    public var note: String

    public init() {
        self.note = ""
    }
    
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "note": return ForeignValue(note)
        default: return nil
        }
    }

    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "note": self.note = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}
