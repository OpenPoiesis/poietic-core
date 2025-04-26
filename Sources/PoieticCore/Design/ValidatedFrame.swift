//
//  ValidatedFrame.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/03/2025.
//

public struct ValidatedFrame: Frame {
    public typealias Snapshot = DesignObject

    /// Stable frame that was validated.
    public let wrapped: DesignFrame
    
    /// Metamodel according to which the frame was validated.
    public let metamodel: Metamodel

    init(_ wrapped: DesignFrame, metamodel: Metamodel) {
        self.wrapped = wrapped
        self.metamodel = metamodel
    }

    @inlinable
    public var design: Design { wrapped.design }
    
    @inlinable
    public var id: FrameID { wrapped.id }
    
    @inlinable
    public var snapshots: [DesignObject] { wrapped.snapshots }
    
    @inlinable
    public func contains(_ id: ObjectID) -> Bool {
        wrapped.contains(id)
    }
    
    @inlinable
    public func object(_ id: ObjectID) -> DesignObject {
        wrapped.object(id)
    }
    
    @inlinable
    public var edgeIDs: [ObjectID] { wrapped.edgeIDs }

    public func outgoing(_ origin: NodeID) -> [Edge] {
        return wrapped.outgoing(origin)
    }
    
    public func incoming(_ target: NodeID) -> [Edge] {
        return wrapped.incoming(target)
    }
}
