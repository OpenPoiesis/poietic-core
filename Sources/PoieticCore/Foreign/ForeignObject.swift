//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 25/09/2023.
//

/// A structure that contains an object representation from a foreign interface.
///
/// The `ForeignObject` structure is used to import and export objects from
/// the object memory.
///
public struct ForeignObject: Codable {
    public enum CodingKeys: String, CodingKey {
        case type
        case id
        case snapshotID
        case name
        case attributes
        // Structural
        case origin = "from"
        case target = "to"
        case children
    }

    /// Type name of the object.
    ///
    /// The type name refers to an ``ObjectType`` in the
    /// metamodel ``Metamodel/objectTypes`` .
    ///
    public let type: String

    // TODO: Change to ForeignAtom?
    /// Reference to an object.
    ///
    ///
    /// When importing, the foreign references can be IDs or object names,
    /// depending on the foreign interface. The IDs must be valid within the
    /// batch of object being imported.
    ///
    /// Using _name_ as an object reference is just for human convenience in
    /// small hand-written designs and should not be used when
    /// importing/exporting objects for non-human use.
    ///
    /// When exporting the IDs are the represented object IDs.
    ///
    /// - SeeAlso: ``name``, ``ObjectSnapshot/id``
    ///
    public let id: String?
    
    public let snapshotID: String?
    
    /// Convenience attribute for object name.
    ///
    /// The name might be also used by foreign interfaces as an object
    /// reference. However, when there are objects with multiple names,
    /// the behaviour is unspecified, typically might result in an error.
    ///
    /// Using _name_ as an object reference is just for human convenience in
    /// small hand-written designs and should not be used when
    /// importing/exporting objects for non-human use.
    ///
    /// If the foreign record contains attribute `name` it will be used
    /// instead of this _name_ attribute of the foreign object.
    ///
    /// - SeeAlso: ``attributes``
    ///
    public let name: String?

    /// Attributes and their values.
    ///
    /// All advertised attributes of components that are
    /// ``InspectableComponent`` are automatically included in the foreign
    /// record.
    ///
    /// If the foreign record contains attribute `name` it will be used
    /// instead of the ``name`` attribute of the foreign object.
    ///
    /// - Note: The attribute values must not contain any object references.
    ///
    /// - SeeAlso: ``InspectableComponent``, ``name``
    ///
    public let attributes: ForeignRecord?

    // Structural properties
    // TODO: Change to ForeignAtom?
    /// Origin of an edge if the structural type of the object is an edge.
    ///
    /// The attribute must be present together with the ``target`` attribute.
    /// The attribute must not be present for any non-edge structure.
    ///
    /// - SeeAlso: ``id``, ``StructuralComponent``
    ///
    public let origin: String?
    // TODO: Change to ForeignAtom?

    /// Target of an edge if the structural type of the object is an edge.
    ///
    /// The attribute must be present together with the ``origin`` attribute.
    /// The attribute must not be present for any non-edge structure.
    ///
    /// - SeeAlso: ``id``, ``StructuralComponent``
    ///
    public let target: String?
    // TODO: Change to [ForeignAtom]

    /// List of references to the object's children to form the object
    /// hierarchy.
    ///
    /// - SeeAlso: ``id``, ``ObjectSnapshot/children``
    ///
    public let children: [String]?
}
