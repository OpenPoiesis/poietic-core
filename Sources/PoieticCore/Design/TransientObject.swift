//
//  MutableObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//


@usableFromInline
class _TransientSnapshotBox: Identifiable {
    // IMPORTANT: Make sure that the self.id is _always_ object ID, not a snapshot ID here.
    /// Object ID
    ///
    @usableFromInline
    var id: ObjectID
   
    // original(snap), new(snapshot), newmut(snap), origmut(snap)
    
    // FIXME: Move the original/new flag from enum here, to struct
    enum Content {
        case stable(isOriginal: Bool, object: ObjectSnapshot)
        case transient(isNew: Bool, object: TransientObject)
    }
    
    var content: Content
    
    init(_ snapshot: ObjectSnapshot, isOriginal: Bool) {
        self.id = snapshot.objectID
        content = .stable(isOriginal: isOriginal, object: snapshot)
    }
    init(_ mutable: TransientObject, isNew: Bool) {
        self.id = mutable.objectID
        content = .transient(isNew: isNew, object: mutable)
    }
    
    var isOriginal: Bool {
        switch content {
        case .stable(let flag, _): flag
        case .transient(_, _): false
        }
    }
    
    var isMutable: Bool {
        switch content {
        case .stable(_, _): false
        case .transient(_, _): true
        }
    }
    
    var hasChanges: Bool {
        switch content {
        case let .transient(isNew: newFlag, object: object): newFlag || object.hasChanges
        case let .stable(isOriginal: isOriginalFlag, object: _): !isOriginalFlag
        }
    }
    
    var objectID: ObjectID {
        switch content {
        case let .stable(_, snapshot): snapshot.objectID
        case let .transient(_, object): object.objectID
        }
    }

    var snapshotID: ObjectSnapshotID {
        switch content {
        case let .stable(_, snapshot): snapshot.snapshotID
        case let .transient(_, object): object.snapshotID
        }
    }
    
    var parent: ObjectID? {
        switch content {
        case let .stable(_, snapshot): snapshot.parent
        case let .transient(_, object): object.parent
        }
    }
    
    var children: ChildrenSet {
        switch content {
        case let .stable(_, snapshot): snapshot.children
        case let .transient(_, object): object.children
        }
    }
    
    var structure: Structure {
        switch content {
        case let .stable(_,snapshot): snapshot.structure
        case let .transient(_, object): object.structure
        }
    }
    
    func asSnapshot() -> ObjectSnapshot {
        switch content {
        case let .stable(_, object): object
        case let .transient(_, snapshot):
            ObjectSnapshot(id: snapshot.snapshotID,
                           body: snapshot._body)
        }
    }
}

/// An object that can be modified before being inserted into a frame.
///
/// Transient objects have short life time and should exist only for the purpose of constructing
/// a transaction for a change. New objects are created within a ``TransientFrame`` using
/// ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``.
/// Mutable versions of existing stable objects are created with``TransientFrame/mutate(_:)``.
///
/// Transient objects are converted to stable objects in ``Design/accept(_:appendHistory:)``.
///
/// - SeeAlso: ``TransientFrame``, ``Design/accept(_:appendHistory:)``
///
public class TransientObject: ObjectProtocol {
    
    @usableFromInline
    package var snapshotID: ObjectSnapshotID
    @usableFromInline
    package var _body: ObjectBody
    
    /// Flag to denote whether the object's parent-child hierarchy has been modified,
    public private(set) var hierarchyChanged: Bool
    public private(set) var componentsChanged: Bool

    /// Set of changed attributes.
    ///
    /// Any attempt to set an attribute is considered a change, despite the new value might be the
    /// same as the original value.
    ///
    public private(set) var changedAttributes: Set<String>

    var hasChanges: Bool { !changedAttributes.isEmpty || hierarchyChanged || componentsChanged }
    
    public init(type: ObjectType,
                snapshotID: ObjectSnapshotID,
                objectID: ObjectID,
                structure: Structure = .unstructured,
                parent: ObjectID? = nil,
                children: [ObjectID] = [],
                attributes: [String:Variant] = [:]) {
        
        self.snapshotID = snapshotID
        self._body = ObjectBody(id: objectID,
                                 type: type,
                                 structure: structure,
                                 parent: parent,
                                 children: children,
                                 attributes: attributes)
        self.changedAttributes = Set()
        self.hierarchyChanged = false
        self.componentsChanged = false
    }

    init(original: ObjectSnapshot, snapshotID: ObjectSnapshotID) {
        self.snapshotID = snapshotID
        self._body = original._body
        self.changedAttributes = Set()
        self.hierarchyChanged = false
        self.componentsChanged = false
    }
   
    @inlinable public var objectID: ObjectID { _body.id }
    @inlinable public var type: ObjectType { _body.type }
    @inlinable public var structure: Structure {
        get { _body.structure }
        set(structure) { _body.structure = structure }
        
    }
    
    public var parent: ObjectID? {
        get { _body.parent }
        set(parent) {
            hierarchyChanged = true
            _body.parent = parent
        }
    }
    
    @inlinable public var children: ChildrenSet { _body.children }
    @inlinable public var attributes: [String:Variant] { _body.attributes }

    /// Get a value for an attribute.
    ///
    @inlinable
    public func attribute(forKey key: String) -> Variant? {
        attributes[key]
    }
    
    public var attributeKeys: [AttributeKey] {
        return Array(attributes.keys)
    }

    public subscript(key: String) -> Variant? {
        get {
            attribute(forKey: key)
        }
        set(value) {
            if let value {
                setAttribute(value: value, forKey: key)
            }
            else {
                removeAttribute(forKey: key)
            }
            
        }
    }
    
    /// Set an attribute value for given key.
    ///
    /// - Precondition: The attribute must not be a reserved attribute (``ReservedAttributeNames``).
    ///
    public func setAttribute(value: Variant, forKey key: String) {
        _body.attributes[key] = value
        changedAttributes.insert(key)
    }
    
    /// Try to set an attribute that is defined by object's type as numeric (int or float) from
    /// a string value.
    ///
    /// This method is typically used to set numeric attributes in user interface from text fields.
    ///
    /// - Returns: `true` if the attribute was successfully converted to a number and set, otherwise
    ///   false. Also returns `false` when the attribute is not numeric or does not exist.
    ///
    public func setNumericAttribute(_ attribute: String, fromString string: String) -> Bool {
        guard let valueType = type.attribute(attribute)?.type else { return false }
        let variant: Variant
        switch valueType {
        case .int:
            guard let number = Int(string) else { return false }
            variant = PoieticCore.Variant(number)
        case .double:
            guard let number = Double(string) else { return false }
            variant = PoieticCore.Variant(number)
        default:
            return false
        }
        self[attribute] = variant
        return true
    }
    
    public func removeAttribute(forKey key: String) {
        _body.attributes[key] = nil
    }

    public func removeChild(_ child: ObjectID) {
        hierarchyChanged = true
        _body.children.remove(child)
    }
    public func addChild(_ child: ObjectID) {
        hierarchyChanged = true
        _body.children.add(child)
    }


}
