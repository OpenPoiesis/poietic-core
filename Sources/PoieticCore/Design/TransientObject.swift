//
//  MutableObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//


// FIXME: Remove this
/// List of attribute names that are reserved and should not be used.
///
public let ReservedAttributeNames = [
    "id", "snapshot_id", "origin", "target", "type", "parent", "structure",
]

class _TransientSnapshotBox: Identifiable {
    var id: ObjectID
    
    enum Content {
        case stable(isOriginal: Bool, object: ObjectSnapshot)
        case mutable(MutableObject)
    }
    
    var content: Content
    
    init(_ snapshot: ObjectSnapshot, isOriginal: Bool) {
        self.id = snapshot.objectID
        content = .stable(isOriginal: isOriginal, object: snapshot)
    }
    init(_ mutable: MutableObject) {
        self.id = mutable.objectID
        content = .mutable(mutable)
    }
    
    var isOriginal: Bool {
        switch content {
        case .stable(let flag, _): flag
        case .mutable(_): false
        }
    }
    
    var isMutable: Bool {
        switch content {
        case .stable(_, _): false
        case .mutable(_): true
        }
    }
    
    var hasChanges: Bool {
        switch content {
        case let .mutable(snapshot): snapshot.original == nil || snapshot.hasChanges
        case let .stable(isOriginal: isOriginalFlag, object: _): !isOriginalFlag
        }
    }
    
    var objectID: ObjectID {
        switch content {
        case let .stable(_, snapshot): snapshot.objectID
        case let .mutable(object): object.objectID
        }
    }

    var snapshotID: EntityID {
        switch content {
        case let .stable(_, snapshot): snapshot.snapshotID
        case let .mutable(object): object.snapshotID
        }
    }
    
    var parent: ObjectID? {
        switch content {
        case let .stable(_, snapshot): snapshot.parent
        case let .mutable(object): object.parent
        }
    }
    
    var children: ChildrenSet {
        switch content {
        case let .stable(_, snapshot): snapshot.children
        case let .mutable(object): object.children
        }
    }
    
    var structure: Structure {
        switch content {
        case let .stable(_,snapshot): snapshot.structure
        case let .mutable(object): object.structure
        }
    }
    
    func asSnapshot() -> ObjectSnapshot {
        switch content {
        case let .stable(_, object): object
        case let .mutable(snapshot):
            ObjectSnapshot(id: snapshot.snapshotID,
                           body: snapshot._body,
                           components: snapshot.components)
        }
    }
}

/// Transient object that can be modified.
///
/// Mutable objects are temporary and typically exist only during a change
/// transaction. New objects are created within a ``TransientFrame`` by ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``.
/// Mutable versions of existing stable objects are created with``TransientFrame/mutate(_:)``.
///
/// Mutable objects are converted to stable objects with ``Design/accept(_:appendHistory:)``.
///
/// - SeeAlso: ``TransientFrame``, ``Design/accept(_:appendHistory:)``
///
public class MutableObject: ObjectSnapshotProtocol {
    // TODO: [WIP] Rename to "TransientSnapshot" or "MutableSnapshot"
    @usableFromInline
    package var _id: ObjectID
    @usableFromInline
    package var _body: _ObjectBody
    public var components: ComponentSet
    
    public private(set) var hierarchyChanged: Bool
    public private(set) var changedAttributes: Set<String>
    public private(set) var original: ObjectSnapshot?

    var hasChanges: Bool { !changedAttributes.isEmpty && hierarchyChanged }
    
    public init(type: ObjectType,
                snapshotID: EntityID,
                objectID: ObjectID,
                structure: Structure = .unstructured,
                parent: ObjectID? = nil,
                children: [ObjectID] = [],
                attributes: [String:Variant] = [:],
                components: [any Component] = []) {
        
        precondition(ReservedAttributeNames.allSatisfy({ attributes[$0] == nil}),
                     "The attributes must not contain any reserved attribute")
        
        self._id = snapshotID
        self._body = _ObjectBody(id: objectID,
                                 type: type,
                                 structure: structure,
                                 parent: parent,
                                 children: children,
                                 attributes: attributes)
        self.components = ComponentSet(components)
        self.changedAttributes = Set()
        self.hierarchyChanged = false
    }

    init(original: ObjectSnapshot, snapshotID: EntityID) {
        self._id = original.snapshotID
        self._body = _ObjectBody(id: original.objectID,
                                 type: original.type,
                                 structure: original.structure,
                                 parent: original.parent,
                                 children: Array(original.children),
                                 attributes: original.attributes)
        self.components = original.components
        self.changedAttributes = Set()
        self.hierarchyChanged = false
    }
   
    @inlinable public var objectID: ObjectID { _body.id }
    @inlinable public var snapshotID: ObjectID { self._id }
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
        precondition(ReservedAttributeNames.firstIndex(of: "key") == nil,
                     "Trying to set a reserved read-only attribute '\(key)'")
        _body.attributes[key] = value
        changedAttributes.insert(key)
    }
    
    public func removeAttribute(forKey key: String) {
        _body.attributes[key] = nil
    }

    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return components[componentType]
        }
        set(component) {
            components[componentType] = component
        }
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
