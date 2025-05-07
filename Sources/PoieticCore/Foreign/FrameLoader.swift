//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation

/// Error thrown by a foreign frame loader.
///
/// - SeeAlso: ``ForeignFrameLoader/load(_:into:)``
///
public enum FrameLoaderError: Error, Equatable, CustomStringConvertible {
    case foreignObjectError(ForeignObjectError, Int, ForeignObjectReference?)
    case unknownObjectType(String, Int, ForeignObjectReference?)
    // TODO: Rename to unknownNamedReference
    case invalidReference(String, ForeignObjectReference?, Int, ForeignObjectReference?)
    case structureMismatch(StructuralType, Int, ForeignObjectReference?)

    public var description: String {
        switch self {
        case let .foreignObjectError(error, index, ref):
            let refString = ref.map { String(describing: $0) } ?? "no reference"
            return "Foreign object error \(error) in object at index \(index) (\(refString))"
        case let .unknownObjectType(type, index, ref):
            let refString = ref.map { String(describing: $0) } ?? "no reference"
            return "Unknown object type '\(type)' in object at index \(index) (\(refString))"
        case let .structureMismatch(type, index, ref):
            let refString = ref.map { String(describing: $0) } ?? "no reference"
            return "Structural mismatch. Expected \(type) in object at index \(index) (\(refString))"
        case let .invalidReference(property, ref, index, ownerRef):
            let refString = ref.map { "'\($0)'" } ?? "(no reference)"
            let ownerString = ownerRef.map { String(describing: $0) } ?? "no reference"
            return "Invalid reference \(refString) for \(property) in object at index \(index) (\(ownerString))"
        }
    }
    
}

/// Object that loads foreign frames into a mutable frame and resolves object
/// references.
///
public final class ForeignFrameLoader {
    /// References to objects that already exist in the frame. The key might
    /// be either an object name or a string representation of an object ID.
    ///
    public var references: [String: ObjectID]

    public init() {
        self.references = [:]
    }
    
    /// Incrementally read frame data into a mutable frame.
    ///
    /// For each object in the collection, in the order as provided:
    ///
    /// 1. get a concrete object type instance from the frame's design metamodel
    /// 2. create an object snapshot in the frame using the given object type
    ///    and a foreign record representing the attributes. The structure
    ///    is not yet set-up.
    ///
    /// When all the objects are instantiated and inserted in the frame, then
    /// for each object:
    ///
    /// 1. Graph structure is created
    /// 2. Hierarchical parent-child structure is created.
    ///
    /// Object references used can be either object names or object IDs.
    ///
    /// Requirements:
    ///
    /// - Object references must be valid from within the collection of objects
    ///   provided or from within previous collections read.
    ///   Otherwise ``ForeignFrameError/invalidReference(_:_:_:)``
    ///   is thrown on the first invalid reference.
    /// - Edges must have both origin and target specified, otherwise
    ///   ``ForeignFrameError/foreignObjectError(_:_:)`` is thrown.
    /// - Other structural types must not have neither origin neither target
    ///   specified.
    ///
    /// - Note: This function is non-transactional. The frame is assumed to
    ///         represent a transaction. When the function fails, the whole
    ///         frame should be discarded.
    /// - Throws: ``FrameLoaderError``
    /// - SeeAlso: ``Design/allocateID(required:)``,
    ///     ``TransientFrame/insert(_:)``
    ///
    public func load(_ foreignFrame: some ForeignFrameProtocol, into frame: TransientFrame) throws (FrameLoaderError) {
        var ids: [(ObjectID, SnapshotID)] = []
        
        let foreignObjects = foreignFrame.objects
        let design = frame.design
        let metamodel = design.metamodel
        
        var snapshots: [MutableObject] = []
        
        // 1. Allocate identities and collect references
        for (index, foreignObject) in foreignObjects.enumerated() {
            guard let id = resolveReference(foreignObject.idReference, in: frame, required: false, type: .object) else {
                // TODO: Use string value for object reference
                throw .invalidReference("id", foreignObject.idReference, index, foreignObject.idReference)
            }
            guard let snapshotID = resolveReference(foreignObject.snapshotIDReference, in: frame, type: .snapshot) else {
                throw .invalidReference("snapshot_id", foreignObject.snapshotIDReference, index, foreignObject.idReference)
            }

            ids.append((id, snapshotID))
        }
        
        // 2. Instantiate objects
        //
        var parents: [(ObjectID, ObjectID)] = []
        
        for (index, foreignObject) in foreignObjects.enumerated() {
            let (id, snapshotID) = ids[index]
            
            let structure: Structure
            
            guard let typeName = foreignObject.type else {
                throw .foreignObjectError(.propertyNotFound("type"), index, foreignObject.idReference)
            }
            
            guard let type = metamodel.objectType(name: typeName) else {
                throw .unknownObjectType(typeName, index, foreignObject.idReference)
            }

            switch (foreignObject.structure, type.structuralType) {
            case (.unstructured, .unstructured), (.none, .unstructured):
                structure = .unstructured
            case (.node, .node), (.none, .node):
                structure = .node
            case (.edge(let originRef, let targetRef), .edge):
                guard let origin = resolveReference(originRef, in: frame, type: .object) else {
                    throw .invalidReference("origin", originRef, index, foreignObject.idReference)
                }
                guard let target = resolveReference(targetRef, in: frame, type: .object) else {
                    throw .invalidReference("target", targetRef, index, foreignObject.idReference)
                }
                structure = .edge(origin, target)
            default:
                throw .structureMismatch(type.structuralType, index, foreignObject.idReference)
            
            }
            
            var attributes = foreignObject.attributes

            if case let .string(name) = foreignObject.idReference, attributes["name"] == nil {
                attributes["name"] = Variant(name)
            }

            let parent: ObjectID?
            if let parentRef = foreignObject.parentReference {
                parent = resolveReference(parentRef, in: frame, type: .object)
            }
            else {
                parent = nil
            }

            let snapshot = frame.create(type,
                                        id: id,
                                        snapshotID: snapshotID,
                                        structure: structure,
                                        attributes: attributes)
            if let parent {
                parents.append((id, parent))
            }
            
            snapshots.append(snapshot)
        }
        
        // 3. Update parents
        for (id, parent) in parents {
            frame.addChild(id, to: parent)
        }
        
    }
    
    /// Try to resolved a foreign object reference.
    ///
    /// - Object references provided as IDs are passed as they are provided.
    /// - Integer references are tried to be converted to IDs and returned as such.
    /// - String references are tried to be converted to ObjectIDs. If conversion was
    ///   successful, then ObjectID is returned. If not, then:
    ///     - If there is an ObjectID with the same name in the reference map, then it is returned.
    ///     - If not, then a new ID is allocated and it is is stored in a reference map.
    ///       Newly allocated ID is returned.
    ///
    public func resolveReference(_ ref: ForeignObjectReference?, in frame: some Frame, required: Bool = true, type: IdentityType) -> ObjectID? {
        guard let ref else {
            // FIXME: [WIP] Release reserved IDs
            return frame.design.createAndReserve(type: type)
        }
        switch ref {
        case let .id(value):
            return value
        case let .int(value):
            if let uint = UInt64(exactly: value) {
                return ObjectID(uint)
            }
            else {
                return nil
            }
        case let .string(string):
            if let id = references[string] {
                return id
            }
            else if required {
                return nil
            }
            else {
                // FIXME: [WIP] Release reserved IDs
                let newID = frame.design.createAndReserve(type: type)
                references[string] = newID
                return newID
            }
        }
    }
}
