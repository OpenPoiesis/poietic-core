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
///
/// - Note: In the future, case insensitivity will be introduced.
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
                // TODO: Lowercase (without locale - see the IMPORTANT note above)
                name.append(char)
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
