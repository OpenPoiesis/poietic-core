//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/07/2023.
//

extension Trait {
    public static let Name = Trait(
        name: "Name",
        attributes: [
            Attribute("name", type: .string,
                      abstract: "Object name"),
        ]
    )
    
    public static let AudienceLevel = Trait(
        name: "AudienceLevel",
        attributes: [
            Attribute("audienceLevel", type: .int, required: false,
                      abstract: "Intended level of expertise of the audience interacting with the object"),
        ]
    )

    public static let Documentation = Trait(
        name: "Documentation",
        attributes: [
            Attribute("abstract", type: .string, default: "", required: false,
                      abstract: "Short abstract about the object."),
            Attribute("documentation", type: .string, default: "", required: false,
                      abstract: "Longer object documentation."),
        ]
    )
 
    public static let Keywords = Trait(
        name: "Keywords",
        attributes: [
            Attribute("keywords", type: .array(.string), default: ForeignValue(Array<String>()),
                      abstract: "List of keywords"),
        ]
    )
    
    public static var Note = Trait(
        name: "Note",
        attributes: [
            Attribute("note",
                      type: .string,
                      default: "",
                      abstract: "Note text"),
        ]
    )
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

/// Documentation component
///
public struct DocumentationComponent: InspectableComponent {
    public static let trait = Trait.Documentation

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

