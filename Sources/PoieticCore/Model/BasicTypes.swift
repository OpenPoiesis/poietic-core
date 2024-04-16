//
//  BasicTypes.swift
//
//
//  Created by Stefan Urbanek on 11/09/2023.
//

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
}
