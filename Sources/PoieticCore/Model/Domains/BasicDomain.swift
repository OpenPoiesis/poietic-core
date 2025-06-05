//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 10/06/2024.
//

extension Trait {

    // TODO: Consider replacing this trait with a direct object attribute `name`
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
    /// - SeeAlso: ``Frame/object(named:)``, ``ObjectSnapshotProtocol/name``
    ///
    public static let Name = Trait(
        name: "Name",
        attributes: [
            Attribute("name", type: .string, abstract: "Object name"),
        ]
    )
    
    public static let Orderable = Trait(
        name: "Orderable",
        attributes: [
            Attribute("order", type: .int, optional: true, abstract: "Order within a group"),
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
                      abstract: "Short abstract about the object"),
            Attribute("documentation", type: .string, default: "", optional: true,
                      abstract: "Longer object documentation"),
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
            Attribute("keywords", type: .strings, default: Variant(Array<String>()),
                      abstract: "List of keywords"),
        ]
    )
    
    /// Trait for a note or a comment.
    ///
    /// Attributes:
    /// - `note` (string) – note text
    ///
    public static let Note = Trait(
        name: "Note",
        attributes: [
            Attribute("note", type: .string, default: "",
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
    public static let DesignInfo = Trait(
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
    
    public static let BibliographicalReference = Trait(
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

extension ObjectType {
    public static let DesignInfo = ObjectType(
        name: "DesignInfo",
        structuralType: .unstructured,
        traits: [
            Trait.DesignInfo,
            // TODO: Add name, but make it optional.
            // Trait.Name,
            Trait.Documentation,
            Trait.AudienceLevel,
            Trait.Keywords,
        ])
    
    public static let BibliographicalReference = ObjectType(
        name: "BibliographicalReference",
        structuralType: .unstructured,
        traits: [
            Trait.BibliographicalReference,
        ])

    public static let Group = ObjectType(
        name: "Group",
        structuralType: .unstructured,
        traits: [
            Trait.Name,
        ])
}

extension Metamodel {
    /// Metamodel with some basic object types that are typical for multiple
    /// kinds of designs.
    ///
    public static let Basic = Metamodel(
        name: "Basic",
        traits: [
            .Name,
            .DesignInfo,
            .Documentation,
            .AudienceLevel,
            .Keywords,
            .Note,
            .BibliographicalReference,
            .DiagramView,
        ],
        types: [
            .DiagramSettings,
            .DesignInfo,
            .Group,
        ],
        constraints: []
    )
}
