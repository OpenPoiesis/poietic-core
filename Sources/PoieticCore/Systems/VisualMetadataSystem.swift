//
//  VisualMetadataSystem.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/08/2026.
//


/// System that prepares basic visual metadata.
///
/// - **Input:** Design objects from current plane with any of the following traits:
///     - ``Trait/NumericValue``
///     - ``Trait/Color``
/// - **Output:**
///     - ``DisplayValueBounds`` component for `NumericValue` trait.
///     - ``AdaptableColor`` component for `Color` trait.
/// - **Forgiveness:** Nothing to be forgiven.
///
public struct VisualMetadataSystem: System {
    public static func update(_ world: World) throws(InternalSystemError) {
        guard let plane = world.plane else { return }
        
        for object in plane.filter(trait: SimulationDomain.Traits.NumericValue) {
            guard let entity = world.entity(object.objectID) else { continue }
            entity.setComponent(DisplayValueBounds(from: object))
        }

        for object in plane.filter(trait: DiagramDomain.Traits.AccentColor) {
            guard let entity = world.entity(object.objectID),
                  let colorName: String = object["color"],
                  let key = AdaptableColorKey(rawValue: colorName)
            else { continue }
            
            entity.setComponent(AdaptableColor(key))
        }
    }
}
