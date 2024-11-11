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
    case foreignObjectError(ForeignObjectError, String?)
    case unknownObjectType(String, String?)
    case invalidReference(String, String, String?)

    public var description: String {
        switch self {
        case let .foreignObjectError(error, ref):
            if let ref {
                return "Foreign object error: '\(error)' in object '\(ref)'"
            }
            else {
                return "Foreign object error '\(error)'"
            }
        case let .unknownObjectType(type, ref):
            if let ref {
                return "Unknown object type '\(type)' in object '\(ref)'"
            }
            else {
                return "Unknown object type '\(type)'"
            }
        case let .invalidReference(ref, property, owner):
            if let owner {
                return "Invalid reference '\(ref)' for '\(property)' in object '\(owner)'"
            }
            else {
                return "Invalid reference '\(ref)' for '\(property)'"
            }
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
    /// - SeeAlso: ``Design/allocateUnstructuredSnapshot(_:id:snapshotID:)``,
    ///     ``TransientFrame/insert(_:)``
    ///
    public func load(_ foreignFrame: ForeignFrame, into frame: TransientFrame) throws (FrameLoaderError) {
        var ids: [(ObjectID, SnapshotID)] = []
        
        let foreignObjects = foreignFrame.objects
        let design = frame.design
        let metamodel = design.metamodel
        
        var snapshots: [MutableObject] = []
        
        // 1. Allocate identities and collect references
        for object in foreignObjects {
            let actualID: ObjectID
            if let stringID = object.id {
                actualID = design.allocateID(required: ObjectID(stringID))
            }
            else {
                actualID = design.allocateID()
            }

            let actualSnapshotID: ObjectID
                if let stringID = object.snapshotID {
                    actualSnapshotID = design.allocateID(required: ObjectID(stringID))
                }
                else {
                    actualSnapshotID = design.allocateID()
                }

            // TODO: Deprecate, use ID
            if let name = object.name {
                references[name] = actualID
            }
            ids.append((actualID, actualSnapshotID))
        }
        
        // 2. Instantiate objects
        //
        for (index, foreignObject) in foreignObjects.enumerated() {
            let (id, snapshotID) = ids[index]
            
            let structure: StructuralComponent
            
            guard let typeName = foreignObject.type else {
                throw .foreignObjectError(.missingObjectType, foreignObject.id)
            }
            
            guard let type = metamodel.objectType(name: typeName) else {
                throw .unknownObjectType(typeName, foreignObject.id)
            }
            do {
                try foreignObject.validateStructure(type.structuralType)
            }
            catch {
                throw .foreignObjectError(error, foreignObject.id)
            }
            switch type.structuralType {
            case .unstructured:
                structure = .unstructured
            case .node:
                structure = .node
            case .edge:
                let originRef = foreignObject.origin!
                guard let originID = references[originRef] else {
                    throw .invalidReference(originRef, "origin", foreignObject.id)
                }

                let targetRef = foreignObject.target!
                guard let targetID = references[targetRef] else {
                    throw .invalidReference(targetRef, "target", foreignObject.id)
                }

                structure = .edge(originID, targetID)
            }
            
            var fullAttributes = foreignObject.attributes
            if let name = foreignObject.name {
                fullAttributes["name"] = Variant(name)
                references[name] = id
            }

            let snapshot = frame.create(type,
                                        id: id,
                                        snapshotID: snapshotID,
                                        structure: structure,
                                        attributes: fullAttributes)
            
            snapshots.append(snapshot)
        }

        // 3. Make parent-child hierarchy
        //
        // All objects are initialised now.
        for (snapshot, object) in zip(snapshots, foreignObjects) {
            for childRef in object.children {
                guard let childID = references[childRef] else {
                    throw .invalidReference(childRef, "child", object.id)
                }
                frame.addChild(childID, to: snapshot.id)
            }
        }
    }
}
