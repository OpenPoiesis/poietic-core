//
//  ObjectSnapshot.swift
//
//
//  Created by Stefan Urbanek on 2021/10/10.
//

/// Identifier of a design objects.
///
/// The object ID is unique within the frame containing the object.
/// There might be multiple object snapshots representing the same object
/// and therefore have the same object ID.
///
/// - SeeAlso: ``ObjectSnapshot``, ``Design``,
///     ``Design/allocateID(required:)``
///
public struct ObjectID: Hashable, Codable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public typealias IntegerLiteralType = UInt64
    var _rawValue: UInt64
    
    // Alias for an internal value, used in allocateID(ObjectID). This is relevant only for
    // integer based IDs and only for current ways of ID generation - sequential. Not needed
    // if we switch to UUID.
    var internalSequenceValue: UInt64 { _rawValue }
    
    init(_ rawValue: UInt64) {
        self._rawValue = rawValue
    }
    
    public init(integerLiteral value: Self.IntegerLiteralType) {
        self._rawValue = value
    }
    
    public init?(_ string: String) {
        guard let value = UInt64(string) else {
            return nil
        }
        self._rawValue = value
    }
    
    public var stringValue: String { String(_rawValue) }
    public var intValue: UInt64 { _rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        self._rawValue = try container.decode(UInt64.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_rawValue)
    }
    public var description: String { stringValue }
}

/// Identifier of a design object version.
///
/// The snapshot ID is unique within a design containing the snapshot.
///
/// SeeAlso: ``ObjectSnapshot``, ``Design``,
///     ``Design/allocateID(required:)``, ``TransientFrame/mutate(_:)``
///
public typealias SnapshotID = ObjectID

/// Identifier of a version frame.
///
/// Each frame in a design has an unique frame ID.
///
/// - SeeAlso: ``Frame``, ``Design/createFrame(deriving:id:)``
///
public typealias FrameID = ObjectID

/// A version of a design object.
///
/// Design objects are the main entities of the design. Each object can have
/// multiple versions and each version is called an _object snapshot_. In the
/// design process the object might exist in different states, based on its
/// mutability and validity. The ``ObjectSnapshot`` protocol provides unified
/// interface for all of those state representations.
///
/// The different representations that the object might be in are:
///
/// - ``DesignObject``: Object that has been validated and can not be modified.
///   They are the items of a``DesignFrame`` and can be shared by multiple frames.
/// - ``MutableObject``: Object of a temporary nature, that can be modified. The
///   Mutable object is then turned into a ``DesignObject`` when valid.
/// - ``TransientObject``: Rather a wrapper over an object that belongs to a
///   ``TransientFrame``, it might refer to an original ``DesignObject`` while
///   the object has not been modified or to a ``MutableObject`` once a
///   modification has been requested.
///
/// Each object object has an unique identity, collection of attributes
/// and might have structural properties. Identity serves as a handle of an
/// object. Attributes define a state of an object. The structural properties
/// define state of the whole design.
///
/// ## Attributes and Object-to-Object References
///
/// All object-to-object references are explicitly managed through either
/// ``structure`` or parent/child relationships. Object attributes can hold any
/// ``Variant``, they can not formally store references to other objects.
///
public protocol ObjectSnapshot: KeyedAttributes, Identifiable where ID == ObjectID {
    /// Primary object identity.
    ///
    /// The object ID defines the main identity of an object within a design.
    /// One object can share multiple snapshots, which are identified by their
    /// ``snapshotID``.
    ///
    /// Objects within a ``Frame`` have unique object ``id``, however there
    /// might be multiple snapshots with the same ``id`` within the design.
    ///
    /// The ID is generated using ``Design/allocateID(required:)`` and is
    /// guaranteed to be unique within the design. If an object is coming from
    /// a foreign interface or from a storage, an explicit ID might be
    /// requested, however the programmer is responsible for checking its
    /// uniqueness within given context.
    ///
    /// - SeeAlso: ``snapshotID``,
    ///    ``Design/allocateID(required:)``,
    ///    ``Frame/object(_:)``,
    ///    ``Frame/contains(_:)-424zf``,
    ///
    var id: ObjectID { get }
    
    /// Unique identifier of the object version snapshot within the design.
    ///
    /// The ``snapshotID`` represents a concrete version of an object. An
    /// object can have multiple versions, which all share the same identity
    /// of object ``id``.
    ///
    /// Typically when working with the design and design frames, one does not
    /// need to use the ``snapshotID``. It is used only when considering
    /// different versions of objects.
    ///
    /// When an object is mutated with ``TransientFrame/mutate(_:)``, the object
    /// ``id`` is preserved, but a new the ``snapshotID`` is generated.
    ///
    /// - SeeAlso: ``id``,
    ///    ``Design/allocateID(required:)``
    ///    ``TransientFrame/mutate(_:)``
    ///
    var snapshotID: SnapshotID { get }
    
    
    /// Object type from the problem domain described by a metamodel.
    ///
    /// The ``ObjectType`` describes the typical object structure within a
    /// domain model. The domain model is described through ``Metamodel``.
    ///
    /// When object is validated and accepted by ``Design/accept(_:appendHistory:)``,
    /// the object attributes and their values must conform to the object type
    /// attributes.
    ///
    /// - SeeAlso:
    ///     ``ObjectType``, ``Metamodel``
    ///     ``Frame/filter(type:)``,
    ///     ``IsTypePredicate``
    ///
    var type: ObjectType { get }

    /// Structural role of the object within a design.
    ///
    /// This property is the only other property to the parent/child hierarchy,
    /// where an object can have references to other objects.
    ///
    /// Primary content of the design is a graph, which has two kinds of
    /// entities: nodes and edges. From the design content perspective, they
    /// are all objects with only difference, that the edge can refer to
    /// other objects.
    ///
    /// Structural component also denotes which objects depend on the object.
    /// For example, if objects is an edge and any of it's ``Structure/edge(_:_:)``
    /// elements is removed from a design, then the edge is removed as well.
    ///
    /// - SeeAlso: ``TransientFrame/removeCascading(_:)``, ``Graph``
    ///
    var structure: Structure { get }
    
    /// Parent of an object in a hierarchical structure.
    ///
    /// When the object's parent is removed from the design, all its children
    /// are removed with it, including their dependencies.
    ///
    /// - SeeAlso: ``children``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``
    ///
    var parent: ObjectID? { get }

    /// Children of an object in a hierarchical structure.
    ///
    /// Children are part of the hierarchical structure of objects. When
    /// an object is removed from a frame, all its children are removed
    /// with it, together with all dependencies.
    ///
    /// - SeeAlso: ``parent``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    var children: ChildrenSet { get }
    
    /// Runtime components of an object.
    ///
    /// - Note: The components are not persisted. They are also not passed
    ///   through foreign interfaces unless a custom functionality is provided.
    ///
    var components: ComponentSet { get }
    
    /// Name of an object.
    ///
    /// Object name is a user-facing property. Use of an object's name depends
    /// on context and on problem domain. For example, in Stock-Flow model
    /// the names of an object is used as a variable in an arithmetic
    /// expression.
    ///
    /// Rules around names, for example whether a name should be unique,
    /// depend on the problem domain.
    ///
    var name: String? { get }
    
    /// Get an attribute value by their name.
    ///
    /// - Returns: attribute value or `nil` when no value is set for given
    ///   attribute.
    ///
    subscript(attributeKey: String) -> Variant? { get }
    
    /// Get a runtime component.
    ///
    subscript<T>(componentType: T.Type) -> T? where T : Component { get }
}

extension ObjectSnapshot {
    /// Get object name if the object has an attribute `name`.
    ///
    /// This is provided for convenience.
    ///
    /// - Note: The `name` attribute must be either a string or an integer,
    ///   otherwise `nil` is returned.
    ///
    public var name: String? {
        guard let value = self["name"] else {
            return nil
        }
        guard case .atom(let atom) = value else {
            return nil
        }

        switch atom {
        case .string(let name): return name
        case .int(let name): return String(name)
        default: return nil
        }
    }
    
    package var unsafeOrigin: ObjectID {
        guard case .edge(let origin, _) = structure else {
            preconditionFailure("Unwrapping non-edge object")
        }
        return origin
    }

    package var unsafeTarget: ObjectID {
        guard case .edge(_, let target) = structure else {
            preconditionFailure("Unwrapping non-edge object")
        }
        return target
    }

    package var unsafeEdgeEndpoints: (ObjectID, ObjectID) {
        guard case .edge(let origin, let target) = structure else {
            preconditionFailure("Unwrapping non-edge object")
        }
        return (origin, target)
    }
}

