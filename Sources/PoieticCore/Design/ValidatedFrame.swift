//
//  ValidatedFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/03/2025.
//

// TODO: A sketch, not yet used
public struct MetamodelValidationMode: OptionSet, Sendable {
    public let rawValue: Int8
    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
    public static let allowUnknownTypes = MetamodelValidationMode(rawValue: 1 << 0)
    public static let allowUnknownEdges = MetamodelValidationMode(rawValue: 1 << 1)
    public static let ignoreConstraints = MetamodelValidationMode(rawValue: 1 << 2)
                                                                                                                                                    
    public static let strict: MetamodelValidationMode = []
    public static let permissive: MetamodelValidationMode = [.allowUnknownTypes, .allowUnknownEdges, .ignoreConstraints]
}

public struct ValidatedFrame: Frame {
    public typealias Snapshot = ObjectSnapshot

    /// Stable frame that was validated.
    public let wrapped: DesignFrame
    
    /// Metamodel according to which the frame was validated.
    public let metamodel: Metamodel

    internal init(_ wrapped: DesignFrame, metamodel: Metamodel) {
        self.wrapped = wrapped
        self.metamodel = metamodel
    }

    @inlinable
    public var design: Design { wrapped.design }
    
    @inlinable
    public var id: FrameID { wrapped.id }
    
    @inlinable
    public var snapshots: [ObjectSnapshot] { wrapped.snapshots }

    @inlinable
    public var objectIDs: [ObjectID] { wrapped.objectIDs }

    @inlinable
    public func contains(_ id: ObjectID) -> Bool {
        wrapped.contains(id)
    }
    
    @inlinable
    public func object(_ id: ObjectID) -> ObjectSnapshot? {
        wrapped.object(id)
    }
    
    @inlinable
    public var nodeKeys: [ObjectID] { wrapped.nodeKeys }
    @inlinable
    public var edgeKeys: [ObjectID] { wrapped.edgeKeys }
    @inlinable
    public var edges: [EdgeObject] { wrapped.edges }
    
    @inlinable
    public func outgoing(_ origin: NodeKey) -> [Edge] {
        return wrapped.outgoing(origin)
    }
    
    @inlinable
    public func incoming(_ target: NodeKey) -> [Edge] {
        return wrapped.incoming(target)
    }
}
