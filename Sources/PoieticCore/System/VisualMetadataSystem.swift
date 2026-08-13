//
//  VisualMetadataSystem.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/08/2026.
//


/// System that prepares basic visual metadata.
///
/// - **Input:** Design objects from current plane with trait ``Trait/NumericValue``.
/// - **Output:** Add ``DisplayValueBounds`` component to the design object entity.
/// - **Forgiveness:** Nothing to be forgiven.
///
public struct VisualMetadataSystem: System {
    public init(_ world: World) { }
    public func update(_ world: World) throws(InternalSystemError) {
        guard let plane = world.plane else { return }
        
        for object in plane.filter(trait: .NumericValue) {
            guard let entity = world.entity(object.objectID) else { continue }
            entity.setComponent(DisplayValueBounds(from: object))
        }
    }
}
