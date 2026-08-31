//
//  NormalizedName.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 30/08/2026.
//

/// Normalised name of an object.
///
/// Normalisation levels
/// 1. Trim whitespaces on both ends: ` population growth ` matches `population growth`
/// 2. Collapse internal whitespaces: `population  growth` matches `population growth`
/// 3. Underscore and space are equivalent: `population_growth` matches `population growth`
/// 4. Case-insensitive: `Population Growth` matches `population growth`
///
/// Presence of this component marks that the object has a name attribute
/// that is non-empty after normalisation.
///
/// - Note: Presence of this component does not imply uniqueness or
///   that the name is not reserved — those are domain concerns.

public struct NormalizedName: Component, Equatable {
    /// Display form of the original name as extracted from the object: trimmed whitespaces and
    /// collapsed internal whitespaces and newlines into a single space.
    public let displayName: String
    /// Normalised key.
    public let key: String


    /// Trim leading and trailing whitespaces and collapse internal whitespaces into a single
    /// space characters.
    public static func displayName(for string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        var wasWhitespace = false
        var name: String = ""
        for char in trimmed {
            if char.isWhitespace {
                guard !wasWhitespace else { continue }
                name.append(" ")
                wasWhitespace = true
            }
            else {
                name.append(char)
                wasWhitespace = false
            }
        }
        return name
    }

    /// Normalise a name.
    ///
    /// Name normalisation:
    /// 1. Whitespaces are trimmed on both ends.
    /// 2. Underscores are treated as whitespaces
    /// 3. Internal whitespaces and underscores are collapsed into one.
    /// 4. All characters are lowercased.
    ///
    public static func normalize(_ string: String) -> String {
        // IMPORTANT: When updating this method, keep the following rules:
        //     - Always preserve diacritics: `café` != `cafe`. No accent stripping.
        //     - Preserve hyphens and other symbols: `a-b` != `a b`
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        var wasWhitespace = false
        var name: String = ""
        for char in trimmed {
            if char.isWhitespace || char == "_" {
                guard !wasWhitespace else { continue }
                name.append("_")
                wasWhitespace = true
            }
            else {
                name.append(char.lowercased())
                wasWhitespace = false
            }
        }
        return name
    }
    
    /// Create a normalised name from a string by trimming spaces and collapsing internal
    /// whitespaces.
    public init(name: String) {
        self.displayName = Self.displayName(for: name)
        self.key = Self.normalize(name)
    }
    
    public func matches(_ other: String) -> Bool {
        return self.key == Self.normalize(other)
    }
    public var isVisuallyEmpty: Bool {
        key.isEmpty || key.allSatisfy { $0 == "_"}
    }
}
