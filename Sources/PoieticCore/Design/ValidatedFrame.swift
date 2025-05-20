//
//  ValidatedFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/03/2025.
//

public struct ValidatedFrame: Frame {
    public typealias Snapshot = ObjectSnapshot

    /// Stable frame that was validated.
    public let wrapped: StableFrame
    
    /// Metamodel according to which the frame was validated.
    public let metamodel: Metamodel

    init(_ wrapped: StableFrame, metamodel: Metamodel) {
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
    public func contains(_ id: ObjectID) -> Bool {
        wrapped.contains(id)
    }
    
    @inlinable
    public func object(_ id: ObjectID) -> ObjectSnapshot {
        wrapped.object(id)
    }
    
    @inlinable
    public var edgeIDs: [ObjectID] { wrapped.edgeIDs }

    public func outgoing(_ origin: NodeKey) -> [Edge] {
        return wrapped.outgoing(origin)
    }
    
    public func incoming(_ target: NodeKey) -> [Edge] {
        return wrapped.incoming(target)
    }
}
