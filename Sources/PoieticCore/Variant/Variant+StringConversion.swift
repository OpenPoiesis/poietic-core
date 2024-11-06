//
//  Variant+StringConversion.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 06/11/2024.
//

import RegexBuilder

// Note: Variant string parsing should not require full JSON parser.
// It is preferable to have variant values JSON-compatible.

extension VariantAtom {
    /// Regex for a JSON number
    ///
    /// - SeeAlso: [rfc8259](https://www.rfc-editor.org/rfc/rfc8259)
    nonisolated(unsafe) static let JSONNumberRegex = Regex {
        Optionally("-")
        ChoiceOf {
            "0"
            OneOrMore(.digit)
        }
        Optionally {
            "."
            OneOrMore(.digit)
        }
        Optionally {
            .anyOf("Ee")
            Optionally(.anyOf("+-"))
            OneOrMore(.digit)
        }
    }

    /// Regex for a point variant.
    ///
    /// Point variant as a string is represented as JSON array with exactly two
    /// numbers: `[x, y]`.
    ///
    /// - SeeAlso: [rfc8259](https://www.rfc-editor.org/rfc/rfc8259)
    ///
    nonisolated(unsafe) static let PointRegex = Regex {
        "["
        ZeroOrMore(.whitespace)
        Capture(JSONNumberRegex)
        ZeroOrMore(.whitespace)
        ","
        ZeroOrMore(.whitespace)
        Capture(JSONNumberRegex)
        ZeroOrMore(.whitespace)
        "]"
    }
}
