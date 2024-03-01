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
        plane: .user,
        traits: [
            Trait.DesignInfo,
            Trait.Documentation,
            Trait.AudienceLevel,
            Trait.Keywords,
        ])

    public static let BibliographicalReference = ObjectType(
        name: "BibliographicalReference",
        structuralType: .unstructured,
        plane: .user,
        traits: [
            Trait.BibliographicalReference,
        ])
}
