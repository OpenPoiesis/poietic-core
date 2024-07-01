//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 30/06/2024.
//

import Foundation

public enum NEWFrameLoaderError: Error, Equatable {
    case foreignObjectError(ForeignObjectError, String?)
    case unknownObjectType(String, String?)
    case invalidReference(String, String, String?)

}

public protocol ForeignObject {
    var type: String? { get }
    var structuralType: StructuralType? { get }

    // FIXME: Depreate name here, use "id"
    var name: String? { get }
    var id: String? { get }
    var snapshotID: String? { get }

    var origin: String? { get }
    var target: String? { get }
    var parent: String? { get }
    var children: [String] { get }
    var attributes: [String:Variant] { get }
}

extension ForeignObject {
    public func validateStructure(_ structuralType: StructuralType) throws (ForeignObjectError) {
        switch structuralType {
        case .unstructured:
            guard origin == nil else {
                throw .extraPropertyFound("from")
            }
            guard target == nil else {
                throw .extraPropertyFound("to")
            }
        case .node:
            guard origin == nil else {
                throw .extraPropertyFound("from")
            }
            guard target == nil else {
                throw .extraPropertyFound("to")
            }
        case .edge:
            guard origin != nil else {
                throw .propertyNotFound("from")
            }
            guard target != nil else {
                throw .propertyNotFound("to")
            }
        }

    }
}

public protocol ForeignFrame {
    var objects: [ForeignObject] { get }
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
    ///   specified, if they do then ``FrameReaderError/invalidStructuralKeyPresent(_:_:_:)``
    ///   is thrown.
    ///
    /// - Note: This function is non-transactional. The frame is assumed to
    ///         represent a transaction. When the function fails, the whole
    ///         frame should be discarded.
    /// - Throws: ``FrameReaderError``
    /// - SeeAlso: ``Design/allocateUnstructuredSnapshot(_:id:snapshotID:)``,
    ///     ``MutableFraminsert(_:owned:):)``
    ///
    public func load(_ foreignFrame: ForeignFrame, into frame: MutableFrame) throws (NEWFrameLoaderError) {
        let foreignObjects = foreignFrame.objects
        let design = frame.design
        let metamodel = design.metamodel
        
        var snapshots: [ObjectSnapshot] = []
        
        var ids: [ObjectID] = []
        var snapshotIDs: [ObjectID] = []
        
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

            // FIXME: Deprecate, use ID
            if let name = object.name {
                references[name] = actualID
            }
            ids.append(actualID)
            snapshotIDs.append(actualSnapshotID)
        }
        
        // 2. Instantiate objects
        //
        for (index, foreignObject) in foreignObjects.enumerated() {
            let id = ids[index]
            let snapshotID = snapshotIDs[index]
            
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
            let snapshot = design.createSnapshot(type,
                                                 id: id,
                                                 snapshotID: snapshotID,
                                                 structure: structure,
                                                 state: .transient)
            
            if let name = foreignObject.name {
                snapshot.setAttribute(value: Variant(name), forKey: "name")
                references[name] = snapshot.id
            }
            
            for (key, value) in foreignObject.attributes {
                snapshot.setAttribute(value: value, forKey: key)
            }
            
            snapshots.append(snapshot)
            snapshot.promote(.stable)
            frame.unsafeInsert(snapshot, owned: true)
        }

        // 3. Make parent-child hierarchy
        //
        // All objects are initialised now.
        // TODO: Do not use addChild, do it in unsafe way, we are ok here.
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
