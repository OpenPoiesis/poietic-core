//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 04/02/2023.
//


/// State of a versioned object snapshot.
///
/// The VersionState denotes how the version snapshot can be used for a mutation
/// of the object itself or for a mutation of its owner.
///
/// Objects can be `transient`, `stable` and `validated`. The following table
/// describes what can be done with the objects in given state:
///
/// |                                | `transient` | `stable` | `validated` |
/// |--------------------------------|-------------|----------|------------|
/// | Change invariant attributes    |     No      |   No     |   No       |
/// | Change versioned attributes    |     Yes     |   No     |   No       |
/// | Change unversioned attributes  |     Yes     |   Yes    |   No       |
/// | Derive new version             |     No      |   Yes    |   Yes      |
///
public enum VersionState: Comparable {
    public static func < (lhs: VersionState, rhs: VersionState) -> Bool {
        switch (lhs, rhs) {
        case (.transient, .transient): true
        case (.transient, .stable): true
        case (.transient, .validated): true
        case (.stable, .transient): false
        case (.stable, .stable): false
        case (.stable, .validated): true
        case (.validated, .transient): false
        case (.validated, .stable): false
        case (.validated, .validated): false
        }
    }
    

    /// Denotes that the version of an object is in the process undergoing
    /// editing.
    ///
    /// Any attributes of the object can be changed and all changes are done
    /// in-place in the same object without creating a new version.
    ///
    /// No derivative versions of the object can be created.
    ///
    case transient

    /// Denotes that the version an object is stable from the user's perspective.
    ///
    /// Attributes that are versioned can not be changed. New versions
    /// can be derived from the object in this state.
    ///
    case stable

    /// Denotes that the version of an object is satisfying constraints.
    ///
    /// The validated object is immutable. The only way to change the object
    /// is to derive a new version.
    ///
    /// - no modification is allowed
    /// - all members should be either frozen or unversioned
    /// - new versions can be derived
    ///
    case validated
    

    /// Flag indicating whether a new version can be derived from an object
    /// in the state.
    ///
    public var canDerive: Bool { return self == .validated || self == .stable }

    /// Flag indicating whether an object in the state can be mutated.
    ///
    public var isMutable: Bool { return self == .stable || self == .transient }
}
