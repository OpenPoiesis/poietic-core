//
//  SemanticVersion.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 04/05/2025.
//


public struct SemanticVersion: Comparable,
                               Hashable,
                               CustomStringConvertible,
                               Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    
    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    public init?(_ string: String) {
        guard !string.isEmpty else { return nil }
        
        let split = string.split(separator: ".")

        switch split.count {
        case 1:
            guard let major = Int(split[0]) else { return nil }
            self.init(major, 0, 0)
        case 2:
            guard let major = Int(split[0]) else { return nil }
            guard let minor = Int(split[1]) else { return nil }
            self.init(major, minor, 0)
        case 3:
            guard let major = Int(split[0]) else { return nil }
            guard let minor = Int(split[1]) else { return nil }
            guard let patch = Int(split[2]) else { return nil }
            self.init(major, minor, patch)
        default:
            return nil
        }
    }
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
    
    public var description: String {
        return "\(major).\(minor).\(patch)"
    }
}

struct SemanticVersionRange: Equatable {
    var lowerBound: SemanticVersion
    var upperBound: SemanticVersion
    func contains(_ version: SemanticVersion) -> Bool {
        return version >= lowerBound && version <= upperBound
    }

}
