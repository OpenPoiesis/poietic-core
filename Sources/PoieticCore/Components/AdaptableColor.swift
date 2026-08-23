//
//  AdaptableColor.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 09/12/2025.
//


public enum AdaptableColorKey: String, CaseIterable, Hashable, Sendable {
    case purple = "purple"
    case red = "red"
    case pink = "pink"
    case brown = "brown"
    case orange = "orange"
    case yellow = "yellow"
    case lime = "lime"
    case green = "green"
    case cyan = "cyan"
    case teal = "teal"
    case blue = "blue"
    case indigo = "indigo"
}

/// Dominant adaptable colour of the object's visual representation.
///
/// The colour is expressed as a key from the adaptable colour palette;
/// the application resolves the key to a concrete colour suitable for its
/// medium and theme (screen, printable output, dark/light).
///
/// - SeeAlso: ``AdaptableColorKey``, ``Trait/Color``
///
public struct AdaptableColor: Component {
    // TODO: Consider renaming to "AccentColor"
    public let key: AdaptableColorKey
                                                                                                                                                                                                            
    public init(_ key: AdaptableColorKey) {
        self.key = key
    }
}
