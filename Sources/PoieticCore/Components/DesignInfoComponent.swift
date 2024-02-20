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
            Attribute("title", type: .array(.string),
                      abstract: "Design title"),
            Attribute("author", type: .array(.string),
                      abstract: "Author of the design"),
            Attribute("license", type: .array(.string),
                      abstract: "License of the design"),
        ]
    )
}

public let DesignObjectType = ObjectType(
    name:"Design",
    structuralType: .unstructured,
    plane: .system,
    traits: [
        Trait.DesignInfo,
        Trait.Documentation,
        Trait.AudienceLevel,
    ])

//struct DesignOriginComponent {
//    let originalAuthor: String?
//    let originalSource: String?
//}

