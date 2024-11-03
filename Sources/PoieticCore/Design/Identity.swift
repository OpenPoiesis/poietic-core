//
//  UniqueIDGenerator.swift
//  
//
//  Created by Stefan Urbanek on 03/01/2022.
//


public typealias ID = UInt64

/// Identifier of a design objects.
///
/// The object ID is unique within the frame containing the object.
/// There might be multiple object snapshots representing the same object
/// and therefore have the same object ID.
///
/// - SeeAlso: ``ObjectSnapshot``, ``Design``,
///     ``Design/allocateID(required:)``
///
public typealias ObjectID = ID

/// Identifier of a design object version.
///
/// The snapshot ID is unique within a design containing the snapshot.
///
/// SeeAlso: ``ObjectSnapshot``, ``Design``,
///     ``Design/allocateID(required:)``, ``TransientFrame/mutableObject(_:)``
///
public typealias SnapshotID = ID

/// Identifier of a version frame.
///
/// Each frame in a design has an unique frame ID.
///
/// - SeeAlso: ``Frame``, ``Design/createFrame(id:)``, ``Design/deriveFrame(original:id:)``
///
public typealias FrameID = ID
