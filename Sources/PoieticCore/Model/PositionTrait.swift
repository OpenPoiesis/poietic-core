//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 06/06/2023.
//

extension Trait {
    /// Trait for objects that can be presented diagrammatically:
    ///
    /// Attributes:
    /// - `position` (``Point``): position of the object on a canvas, typically
    ///   a centre of the object's shape. Please refer to the particular
    ///   domain metamodel for more details.
    /// - `z_index` (`Int`): Order of layering of objects on top of each other.
    ///   Higher number means top – might obscure others,
    ///   lower means bottom - might be obscured.
    ///
    public static let Position = Trait(
        name: "Position",
        attributes: [
            Attribute("position", type: .point, default: Variant(Point(0,0))),
            Attribute("z_index", type: .int, default: Variant(0)),
        ]
    )
}

extension ObjectSnapshot {
    /// Get position of the object.
    ///
    /// The position is retrieved from the `position` attribute, if it is
    /// present. If the object has no `position` attribute or the attribute
    /// is not convertible to a valid point, then `nil` is returned.
    ///
    public var position: Point? {
        get {
            if let value = self["position"] {
                return try? value.pointValue()
            }
            else {
                return nil
            }
        }
    }
}

extension MutableObject {
    /// Get or set position of the object.
    ///
    /// The position is retrieved from the `position` attribute, if it is
    /// present. If the object has no `position` attribute or the attribute
    /// is not convertible to a valid point, then `nil` is returned.
    ///
    public var position: Point? {
        get {
            if let value = self["position"] {
                return try? value.pointValue()
            }
            else {
                return nil
            }
        }
        set(point) {
            if let point {
                self["position"] = .atom(.point(point))
            }
            else {
                self["position"] = nil
            }
        }
    }
}
