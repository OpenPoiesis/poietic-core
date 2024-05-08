//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 09/07/2023.
//

extension Trait {
    /// Trait for objects that have a name.
    ///
    /// Attributes:
    ///
    /// - `name` (string) – name of the object
    ///
    /// Name is typically an identifier through with the object can be
    /// referenced.
    ///
    /// For some types of models, the name might be unique within the whole
    /// model.
    ///
    public static let Name = Trait(
        name: "Name",
        attributes: [
            Attribute("name", type: .string,
                      abstract: "Object name"),
        ]
    )
    
    /// Trait denoting level of expertise of the user.
    ///
    /// This trait is used on objects to set users expectations.
    ///
    /// Attributes:
    /// - `audience_level` (int) – Audience level: 1 - _beginner_, 2 - _intermediate_,
    ///   3 - _advanced_, 4 - _expert_. Any number greater than 4 is assumed to be
    ///   the same as _expert_.
    ///
    public static let AudienceLevel = Trait(
        name: "AudienceLevel",
        attributes: [
            Attribute("audience_level", type: .int, optional: true,
                      abstract: "Intended level of expertise of the audience interacting with the object"),
        ]
    )

    /// Trait for objects that can be documented.
    ///
    /// Attributes:
    /// - `abstract` (string) – short abstract about the object. Typically one
    ///    sentence.
    /// - `documentation` (string) – longer description of the object.
    ///
    public static let Documentation = Trait(
        name: "Documentation",
        attributes: [
            Attribute("abstract", type: .string, default: "", optional: true,
                      abstract: "Short abstract about the object."),
            Attribute("documentation", type: .string, default: "", optional: true,
                      abstract: "Longer object documentation."),
        ]
    )
 
    /// Trait for a list of keywords.
    ///
    /// Attributes:
    /// - `keywords` (list of strings) – List of keywords
    ///
    public static let Keywords = Trait(
        name: "Keywords",
        attributes: [
            Attribute("keywords", type: .array(.string), default: Variant(Array<String>()),
                      abstract: "List of keywords"),
        ]
    )
    
    /// Trait for a note or a comment.
    ///
    /// Attributes:
    /// - `note` (string) – note text
    ///
    public static var Note = Trait(
        name: "Note",
        attributes: [
            Attribute("note",
                      type: .string,
                      default: "",
                      abstract: "Note text"),
        ]
    )
    
    /// Trait for design information.
    ///
    /// This trait is used on an object, typically a singleton
    /// (one instance per design), to provide basic user-oriented information
    /// about the design.
    ///
    /// Applications are expected to create their own `DesignInfo` object type
    /// that might include this trait in addition to the application
    /// specific traits.
    ///
    /// Attributes:
    ///
    /// - `title` – design title
    /// - `author` – name of the design author
    /// - `license` – license by which the design can be used
    ///
    ///
    ///
    public static var DesignInfo = Trait(
        name: "DesignInfo",
        attributes: [
            Attribute("title", type: .string, optional: true,
                      abstract: "Design title"),
            Attribute("author", type: .string, optional: true,
                      abstract: "Author of the design"),
            Attribute("license", type: .string, optional: true,
                      abstract: "License of the design"),
        ]
    )
    
    public static var BibliographicalReference = Trait(
        name: "BibliographicalReference",
        attributes: [
            Attribute("bibliography_type", type: .string, optional: true,
                      abstract: "Bibliographical reference type"),
            Attribute("author", type: .string, optional: true,
                      abstract: "Author of the referenced publication or resource"),
            Attribute("title", type: .string, optional: true,
                      abstract: "Title of the publication or referenced resource"),
            // NOTE: We are reserving "pages" here for the future
            Attribute("book_pages", type: .string, optional: true,
                      abstract: "A string referring to one or multiple pages within the source, if the source is a larger, typically printed medium"),
            Attribute("year", type: .string, optional: true,
                      abstract: "Year of publication"),
            Attribute("publisher", type: .string, optional: true,
                      abstract: "Name of a publisher"),
            Attribute("url", type: .string, optional: true,
                      abstract: "URL to the bibliography source"),
        ]
    )
}

public enum AudienceLevel: Int  {
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

