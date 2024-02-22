//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/09/2023.
//

extension Trait {
    public static var DesignInfo = Trait(
        name: "DesignInfo",
        attributes: [
            Attribute("title", type: .array(.string), optional: true,
                      abstract: "Design title"),
            Attribute("author", type: .array(.string), optional: true,
                      abstract: "Author of the design"),
            Attribute("license", type: .array(.string), optional: true,
                      abstract: "License of the design"),
        ]
    )
}

extension ObjectType {
    public static let DesignInfo = ObjectType(
        name: "DesignInfo",
        structuralType: .unstructured,
        plane: .user,
        traits: [
            Trait.DesignInfo,
            Trait.Documentation,
            Trait.AudienceLevel,
            Trait.Keywords,
        ])
}

//struct DesignOriginComponent {
//    let originalAuthor: String?
//    let originalSource: String?
//}

