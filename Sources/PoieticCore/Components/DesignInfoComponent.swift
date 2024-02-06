//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 11/09/2023.
//

public struct DesignInfoComponent: InspectableComponent {
    public static var componentSchema = ComponentDescription(
        name: "DesignInfo",
        attributes: [
            Attribute(
                name: "title",
                type: .array(.string),
                abstract: "Design title"),
            Attribute(
                name: "author",
                type: .array(.string),
                abstract: "Author of the design"),
            Attribute(
                name: "license",
                type: .array(.string),
                abstract: "License of the design"),
        ]
    )

    /// Title of the design
    var title: String
    
    /// Author of the design
    var author: String
    
    /// License of the design.
    var license: String

    // TODO: Consider the following
    // var genre: String
    // var category: String
    // var subcategory: String
    
    public init() {
        self.title = ""
        self.author = ""
        self.license = ""
    }
    public func attribute(forKey key: AttributeKey) -> ForeignValue? {
        switch key {
        case "title": return ForeignValue(title)
        case "author": return ForeignValue(author)
        case "license": return ForeignValue(license)
        default: return nil
        }
    }
    public mutating func setAttribute(value: ForeignValue,
                                      forKey key: AttributeKey) throws {
        switch key {
        case "title": self.title = try value.stringValue()
        case "author": self.author = try value.stringValue()
        case "license": self.license = try value.stringValue()
        default:
            throw AttributeError.unknownAttribute(name: key,
                                                  type: String(describing: type(of: self)))
        }
    }
}

public let DesignObjectType = ObjectType(
    name:"Design",
    structuralType: .unstructured,
    plane: .system,
    components: [
        DesignInfoComponent.self,
        DocumentationComponent.self,
        AudienceLevelComponent.self,
    ])

//struct DesignOriginComponent {
//    let originalAuthor: String?
//    let originalSource: String?
//}

