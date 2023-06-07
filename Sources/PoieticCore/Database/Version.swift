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
/// Objects can be `frozen`, `transient` and `unstable`. The following table
/// describes what can be done with the objects in given state:
///
/// |                                | `unstable` | `transient` | `frozen` |
/// |--------------------------------|-------------|----------|----------|
/// | Change invariant attributes    |     No      |   No     |   No     |
/// | Change versioned attributes    |     Yes     |   No     |   No     |
/// | Change unversioned attributes  |     Yes     |   Yes    |   No     |
/// | Derive new version             |     No      |   Yes    |   Yes    |
///
public enum VersionState {
    // Validated, transient, unstable
    /// Denotes that the version of an object is immutable and can not become
    /// mutable any more.
    ///
    /// - no modification is allowed
    /// - all members should be either frozen or unversioned
    /// - new versions can be derived
    ///
    case frozen
    
    /// Denotes that the version an object is mutable and one can derive other
    /// versions from it.
    ///
    case transient

    // Can mutate, can not derive version
    /// Denotes that the version of an object is mutable however it is still
    /// being initialised. No derivative versions can be created from an object
    /// in this state,
    case unstable
    
    /// Flag indicating whether a new version can be derived from an object
    /// in the state.
    ///
    public var canDerive: Bool { return self == .frozen || self == .transient }

    /// Flag indicating whether an object in the state can be mutated.
    ///
    public var isMutable: Bool { return self == .transient || self == .unstable }
}

